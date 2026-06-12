package handlers

import (
	"errors"
	"fmt"
	"net/http"

	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/email"
	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
	"github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
	"github.com/eysteinn/jobsiterecords/services/api/internal/workspace"
)

type TeamHandler struct {
	cfg        config.Config
	workspaces *workspace.Service
	mail       *email.Queue
}

func NewTeamHandler(cfg config.Config, ws *workspace.Service, mail *email.Queue) *TeamHandler {
	return &TeamHandler{cfg: cfg, workspaces: ws, mail: mail}
}

type inviteRequest struct {
	Email string `json:"email"`
}

type acceptInviteRequest struct {
	Token string `json:"token"`
}

func (h *TeamHandler) GetTeam(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	team, err := h.workspaces.GetTeam(r.Context(), userID, workspaceID)
	if err != nil {
		writeTeamError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, team)
}

func (h *TeamHandler) CreateInvite(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")

	var req inviteRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}

	inv, plain, err := h.workspaces.CreateInvite(r.Context(), userID, workspaceID, req.Email)
	if err != nil {
		writeTeamError(w, err)
		return
	}

	wsName, _ := h.workspaces.Name(r.Context(), workspaceID)
	if wsName == "" {
		wsName = "your workspace"
	}
	link := fmt.Sprintf("%s/invite/accept?token=%s", h.cfg.AppURL, plain)
	if err := h.mail.SendWorkspaceInvite(r.Context(), inv.Email, wsName, link); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not send invite email", nil)
		return
	}

	resp := map[string]any{"invite": inv}
	if h.cfg.DevLogEmailLinks {
		resp["dev_link"] = link
	}
	httpx.JSON(w, http.StatusCreated, resp)
}

func (h *TeamHandler) ResendInvite(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	inviteID := r.PathValue("inviteID")

	inv, plain, err := h.workspaces.ResendInvite(r.Context(), userID, workspaceID, inviteID)
	if err != nil {
		writeTeamError(w, err)
		return
	}

	wsName, _ := h.workspaces.Name(r.Context(), workspaceID)
	if wsName == "" {
		wsName = "your workspace"
	}
	link := fmt.Sprintf("%s/invite/accept?token=%s", h.cfg.AppURL, plain)
	if err := h.mail.SendWorkspaceInvite(r.Context(), inv.Email, wsName, link); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "internal", "Could not send invite email", nil)
		return
	}

	resp := map[string]any{"invite": inv}
	if h.cfg.DevLogEmailLinks {
		resp["dev_link"] = link
	}
	httpx.JSON(w, http.StatusOK, resp)
}

func (h *TeamHandler) RevokeInvite(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	inviteID := r.PathValue("inviteID")

	if err := h.workspaces.RevokeInvite(r.Context(), userID, workspaceID, inviteID); err != nil {
		writeTeamError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "revoked"})
}

func (h *TeamHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	memberUserID := r.PathValue("memberUserID")

	if err := h.workspaces.RemoveMember(r.Context(), userID, workspaceID, memberUserID); err != nil {
		writeTeamError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "removed"})
}

func (h *TeamHandler) PreviewInvite(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		var body acceptInviteRequest
		if httpx.DecodeJSON(r, &body) == nil {
			token = body.Token
		}
	}
	if token == "" {
		httpx.Error(w, http.StatusBadRequest, "invalid_token", "Missing invite token", nil)
		return
	}

	preview, err := h.workspaces.PreviewInvite(r.Context(), token)
	if err != nil {
		writeTeamError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, preview)
}

func (h *TeamHandler) AcceptInvite(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())

	var req acceptInviteRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	if req.Token == "" {
		httpx.Error(w, http.StatusBadRequest, "invalid_token", "Missing invite token", nil)
		return
	}

	ws, err := h.workspaces.AcceptInvite(r.Context(), userID, req.Token)
	if err != nil {
		writeTeamError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"status":    "accepted",
		"workspace": ws,
	})
}

func writeTeamError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, workspace.ErrNotOwner):
		httpx.Error(w, http.StatusForbidden, "forbidden", "Owner access required", nil)
	case errors.Is(err, workspace.ErrMemberLimit):
		httpx.Error(w, http.StatusConflict, "member_limit", "Workspace is at its member limit", nil)
	case errors.Is(err, workspace.ErrWorkspaceReadOnly):
		httpx.Error(w, http.StatusForbidden, "read_only", "Workspace is read-only", nil)
	case errors.Is(err, workspace.ErrAlreadyMember):
		httpx.Error(w, http.StatusConflict, "already_member", "That person is already a workspace member", nil)
	case errors.Is(err, workspace.ErrInviteNotFound):
		httpx.Error(w, http.StatusNotFound, "not_found", "Invite not found", nil)
	case errors.Is(err, workspace.ErrInvalidInvite):
		httpx.Error(w, http.StatusBadRequest, "invalid_invite", "Invalid or expired invite", nil)
	case errors.Is(err, workspace.ErrEmailMismatch):
		httpx.Error(w, http.StatusForbidden, "email_mismatch", "Sign in with the invited email address to accept", nil)
	case errors.Is(err, workspace.ErrCannotRemoveSelf):
		httpx.Error(w, http.StatusBadRequest, "cannot_remove_self", "You cannot remove yourself", nil)
	case errors.Is(err, workspace.ErrCannotRemoveOwner):
		httpx.Error(w, http.StatusBadRequest, "cannot_remove_owner", "Cannot remove the workspace owner", nil)
	default:
		if err.Error() == "not a workspace member" {
			httpx.Error(w, http.StatusForbidden, "forbidden", err.Error(), nil)
			return
		}
		if err.Error() == "member not found" {
			httpx.Error(w, http.StatusNotFound, "not_found", err.Error(), nil)
			return
		}
		if err.Error() == "invalid email address" {
			httpx.Error(w, http.StatusBadRequest, "invalid_email", err.Error(), nil)
			return
		}
		if err.Error() == "an invite is already pending for this email" {
			httpx.Error(w, http.StatusConflict, "invite_pending", err.Error(), nil)
			return
		}
		httpx.Error(w, http.StatusBadRequest, "bad_request", err.Error(), nil)
	}
}
