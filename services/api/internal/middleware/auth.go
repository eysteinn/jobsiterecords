package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/eysteinn/jobsiterecords/services/api/internal/auth"
	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
)

type ctxKey string

const UserIDKey ctxKey = "userID"
const SessionIDKey ctxKey = "sessionID"

func RequireAuth(secret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := extractBearer(r)
			if token == "" {
				if c, err := r.Cookie("access_token"); err == nil {
					token = c.Value
				}
			}
			if token == "" {
				httpx.Error(w, http.StatusUnauthorized, "unauthorized", "Sign in required", nil)
				return
			}
			claims, err := auth.ParseAccessToken(secret, token)
			if err != nil {
				httpx.Error(w, http.StatusUnauthorized, "unauthorized", "Session expired", nil)
				return
			}
			ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
			ctx = context.WithValue(ctx, SessionIDKey, claims.SessionID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func UserID(ctx context.Context) string {
	v, _ := ctx.Value(UserIDKey).(string)
	return v
}

func SessionID(ctx context.Context) string {
	v, _ := ctx.Value(SessionIDKey).(string)
	return v
}

func extractBearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if !strings.HasPrefix(h, "Bearer ") {
		return ""
	}
	return strings.TrimSpace(strings.TrimPrefix(h, "Bearer "))
}
