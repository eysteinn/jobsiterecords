package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/eysteinn/jobsiterecords/services/api/internal/auth"
	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/email"
	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
	"github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
	"github.com/eysteinn/jobsiterecords/services/api/internal/ratelimit"
	"github.com/eysteinn/jobsiterecords/services/api/internal/workspace"
)

type AuthHandler struct {
	cfg       config.Config
	auth      *auth.Service
	workspaces *workspace.Service
	mail      *email.Queue
	limiter   *ratelimit.Limiter
}

func NewAuthHandler(cfg config.Config, authSvc *auth.Service, wsSvc *workspace.Service, mail *email.Queue, limiter *ratelimit.Limiter) *AuthHandler {
	return &AuthHandler{cfg: cfg, auth: authSvc, workspaces: wsSvc, mail: mail, limiter: limiter}
}

type signupRequest struct {
	Email    string  `json:"email"`
	Password string  `json:"password"`
	Name     *string `json:"name"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type emailRequest struct {
	Email string `json:"email"`
}

type resetRequest struct {
	Token    string `json:"token"`
	Password string `json:"password"`
}

type oauthGoogleRequest struct {
	IDToken string `json:"id_token"`
}

func (h *AuthHandler) SignUp(w http.ResponseWriter, r *http.Request) {
	var req signupRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	if !auth.ValidEmail(req.Email) {
		httpx.Error(w, http.StatusBadRequest, "invalid_email", "Enter a valid email address", nil)
		return
	}
	user, session, err := h.auth.SignUp(r.Context(), req.Email, req.Password, req.Name)
	if err != nil {
		writeAuthError(w, err)
		return
	}
	h.writeSession(w, user, session)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	ip := httpx.ClientIP(r)
	if ok, retry := h.limiter.Allow("login:ip:"+ip, 30, 15*time.Minute); !ok {
		ratelimit.Write429(w, retry)
		return
	}

	var req loginRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	emailNorm := auth.NormalizeEmail(req.Email)
	if ok, retry := h.limiter.Allow("login:email:"+emailNorm, 5, 15*time.Minute); !ok {
		ratelimit.Write429(w, retry)
		return
	}

	user, session, err := h.auth.Login(r.Context(), req.Email, req.Password, deviceLabel(r))
	if err != nil {
		writeAuthError(w, err)
		return
	}
	h.writeSession(w, user, session)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	refresh := refreshFromRequest(r)
	if refresh == "" {
		httpx.Error(w, http.StatusUnauthorized, "unauthorized", "Missing refresh token", nil)
		return
	}
	key := "refresh:" + refresh
	if len(refresh) >= 16 {
		key = "refresh:" + refresh[:16]
	}
	if ok, retry := h.limiter.Allow(key, 60, time.Minute); !ok {
		ratelimit.Write429(w, retry)
		return
	}
	user, session, err := h.auth.Refresh(r.Context(), refresh)
	if err != nil {
		clearSessionCookies(w, h.cfg)
		httpx.Error(w, http.StatusUnauthorized, "unauthorized", "Session expired — sign in again", nil)
		return
	}
	h.writeSession(w, user, session)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	sessionID := middleware.SessionID(r.Context())
	if sessionID != "" {
		_ = h.auth.Logout(r.Context(), sessionID)
	}
	clearSessionCookies(w, h.cfg)
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "signed_out"})
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	user, err := h.auth.GetUser(r.Context(), userID)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "unauthorized", "User not found", nil)
		return
	}
	workspaces, err := h.workspaces.ListForUser(r.Context(), userID)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not load workspaces", nil)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"user":        user,
		"workspaces":  workspaces,
	})
}

func (h *AuthHandler) MagicLink(w http.ResponseWriter, r *http.Request) {
	var req emailRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	emailNorm := auth.NormalizeEmail(req.Email)
	if !auth.ValidEmail(emailNorm) {
		httpx.Error(w, http.StatusBadRequest, "invalid_email", "Enter a valid email address", nil)
		return
	}
	ip := httpx.ClientIP(r)
	if ok, retry := h.limiter.Allow("magic:ip:"+ip, 10, 15*time.Minute); !ok {
		ratelimit.Write429(w, retry)
		return
	}
	if ok, retry := h.limiter.Allow("magic:email:"+emailNorm, 3, 15*time.Minute); !ok {
		ratelimit.Write429(w, retry)
		return
	}

	plain, err := h.auth.CreateMagicLink(r.Context(), emailNorm)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not send magic link", nil)
		return
	}
	link := fmt.Sprintf("%s/auth/verify?token=%s", h.cfg.AppURL, plain)
	if err := h.mail.SendMagicLink(r.Context(), emailNorm, link); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not send magic link", nil)
		return
	}

	resp := map[string]string{"status": "sent", "message": "If that email is registered, a sign-in link is on its way."}
	if h.cfg.DevLogEmailLinks && plain != "" {
		resp["dev_link"] = link
	}
	httpx.JSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) VerifyMagicLink(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		var body struct {
			Token string `json:"token"`
		}
		if httpx.DecodeJSON(r, &body) == nil {
			token = body.Token
		}
	}
	if token == "" {
		if r.Method == http.MethodGet {
			http.Redirect(w, r, h.cfg.AppURL+"/login?error=invalid_link", http.StatusFound)
			return
		}
		httpx.Error(w, http.StatusBadRequest, "invalid_token", "Missing token", nil)
		return
	}
	user, session, err := h.auth.VerifyMagicLink(r.Context(), token, deviceLabel(r))
	if err != nil {
		if r.Method == http.MethodGet {
			http.Redirect(w, r, h.cfg.AppURL+"/login?error=invalid_link", http.StatusFound)
			return
		}
		httpx.Error(w, http.StatusBadRequest, "invalid_token", "Invalid or expired link", nil)
		return
	}
	if r.Method == http.MethodGet {
		setSessionCookies(w, h.cfg, session)
		http.Redirect(w, r, h.cfg.AppURL+"/jobs", http.StatusFound)
		return
	}
	h.writeSession(w, user, session)
}

func (h *AuthHandler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req emailRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	emailNorm := auth.NormalizeEmail(req.Email)
	if ok, retry := h.limiter.Allow("forgot:email:"+emailNorm, 3, time.Hour); !ok {
		ratelimit.Write429(w, retry)
		return
	}
	plain, err := h.auth.CreatePasswordReset(r.Context(), emailNorm)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not process request", nil)
		return
	}
	resp := map[string]string{"status": "sent", "message": "If that email is registered, reset instructions are on their way."}
	if plain != "" {
		link := fmt.Sprintf("%s/reset-password?token=%s", h.cfg.AppURL, plain)
		if err := h.mail.SendPasswordReset(r.Context(), emailNorm, link); err != nil {
			httpx.Error(w, http.StatusInternalServerError, "internal", "Could not send reset email", nil)
			return
		}
		if h.cfg.DevLogEmailLinks {
			resp["dev_link"] = link
		}
	}
	httpx.JSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) OAuthGoogle(w http.ResponseWriter, r *http.Request) {
	if len(h.cfg.GoogleClientIDs) == 0 {
		httpx.Error(w, http.StatusServiceUnavailable, "oauth_not_configured", "Google sign-in is not configured", nil)
		return
	}

	ip := httpx.ClientIP(r)
	if ok, retry := h.limiter.Allow("oauth:google:ip:"+ip, 10, 15*time.Minute); !ok {
		ratelimit.Write429(w, retry)
		return
	}

	var req oauthGoogleRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	if req.IDToken == "" {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Missing id_token", nil)
		return
	}

	user, session, err := h.auth.LoginWithGoogle(r.Context(), req.IDToken, deviceLabel(r))
	if err != nil {
		writeAuthError(w, err)
		return
	}
	h.writeSession(w, user, session)
}

func (h *AuthHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	var req resetRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	if err := h.auth.ResetPassword(r.Context(), req.Token, req.Password); err != nil {
		writeAuthError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "password_updated"})
}

func (h *AuthHandler) writeSession(w http.ResponseWriter, user auth.User, session auth.SessionPair) {
	setSessionCookies(w, h.cfg, session)
	httpx.JSON(w, http.StatusOK, map[string]any{
		"user":          user,
		"access_token":  session.AccessToken,
		"refresh_token": session.RefreshToken,
	})
}

func writeAuthError(w http.ResponseWriter, err error) {
	switch err {
	case auth.ErrWeakPassword:
		httpx.Error(w, http.StatusBadRequest, "weak_password", "Password must be at least 10 characters", nil)
	case auth.ErrCommonPassword:
		httpx.Error(w, http.StatusBadRequest, "weak_password", "Choose a less common password", nil)
	case auth.ErrInvalidPassword:
		httpx.Error(w, http.StatusUnauthorized, "invalid_credentials", "Invalid email or password", nil)
	case auth.ErrInvalidOAuthToken:
		httpx.Error(w, http.StatusUnauthorized, "invalid_token", "Invalid or expired sign-in token", nil)
	case auth.ErrEmailNotVerified:
		httpx.Error(w, http.StatusBadRequest, "email_not_verified", "Google account email is not verified", nil)
	case auth.ErrOAuthNotConfigured:
		httpx.Error(w, http.StatusServiceUnavailable, "oauth_not_configured", "Google sign-in is not configured", nil)
	default:
		if err.Error() == "email already registered" {
			httpx.Error(w, http.StatusConflict, "email_taken", "An account with this email already exists", nil)
			return
		}
		if err.Error() == "invalid or expired link" || err.Error() == "invalid or expired reset link" {
			httpx.Error(w, http.StatusBadRequest, "invalid_token", err.Error(), nil)
			return
		}
		httpx.Error(w, http.StatusBadRequest, "bad_request", err.Error(), nil)
	}
}

func deviceLabel(r *http.Request) *string {
	ua := r.UserAgent()
	if ua == "" {
		return nil
	}
	if len(ua) > 120 {
		ua = ua[:120]
	}
	return &ua
}

func refreshFromRequest(r *http.Request) string {
	if c, err := r.Cookie("refresh_token"); err == nil {
		return c.Value
	}
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if httpx.DecodeJSON(r, &body) == nil && body.RefreshToken != "" {
		return body.RefreshToken
	}
	return ""
}

func setSessionCookies(w http.ResponseWriter, cfg config.Config, session auth.SessionPair) {
	http.SetCookie(w, &http.Cookie{
		Name:     "access_token",
		Value:    session.AccessToken,
		Path:     "/",
		HttpOnly: true,
		Secure:   cfg.CookieSecure,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   cfg.AccessTokenTTL * 60,
	})
	http.SetCookie(w, &http.Cookie{
		Name:     "refresh_token",
		Value:    session.RefreshToken,
		Path:     "/",
		HttpOnly: true,
		Secure:   cfg.CookieSecure,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   cfg.RefreshTokenDays * 24 * 60 * 60,
	})
}

func clearSessionCookies(w http.ResponseWriter, cfg config.Config) {
	for _, name := range []string{"access_token", "refresh_token"} {
		http.SetCookie(w, &http.Cookie{
			Name:     name,
			Value:    "",
			Path:     "/",
			HttpOnly: true,
			Secure:   cfg.CookieSecure,
			SameSite: http.SameSiteLaxMode,
			MaxAge:   -1,
		})
	}
}

type WorkspaceHandler struct {
	workspaces *workspace.Service
}

func NewWorkspaceHandler(ws *workspace.Service) *WorkspaceHandler {
	return &WorkspaceHandler{workspaces: ws}
}

func (h *WorkspaceHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	items, err := h.workspaces.ListForUser(r.Context(), userID)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not load workspaces", nil)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"workspaces": items})
}

func (h *WorkspaceHandler) Leave(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	if err := h.workspaces.Leave(r.Context(), userID, workspaceID); err != nil {
		httpx.Error(w, http.StatusBadRequest, "leave_failed", err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "left"})
}
