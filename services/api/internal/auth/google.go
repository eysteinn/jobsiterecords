package auth

import (
	"context"
	"fmt"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
)

type GoogleClaims struct {
	Sub           string
	Email         string
	EmailVerified bool
	Name          *string
}

type GoogleVerifier struct {
	verifier *oidc.IDTokenVerifier
	audiences map[string]struct{}
}

func NewGoogleVerifier(ctx context.Context, clientIDs []string) (*GoogleVerifier, error) {
	if len(clientIDs) == 0 {
		return nil, nil
	}
	provider, err := oidc.NewProvider(ctx, "https://accounts.google.com")
	if err != nil {
		return nil, fmt.Errorf("google oidc provider: %w", err)
	}
	verifier := provider.Verifier(&oidc.Config{SkipClientIDCheck: true})
	audiences := make(map[string]struct{}, len(clientIDs))
	for _, id := range clientIDs {
		id = strings.TrimSpace(id)
		if id != "" {
			audiences[id] = struct{}{}
		}
	}
	return &GoogleVerifier{verifier: verifier, audiences: audiences}, nil
}

func (v *GoogleVerifier) Verify(ctx context.Context, rawIDToken string) (GoogleClaims, error) {
	if v == nil || v.verifier == nil {
		return GoogleClaims{}, ErrOAuthNotConfigured
	}
	token, err := v.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return GoogleClaims{}, ErrInvalidOAuthToken
	}
	audOK := false
	for _, aud := range token.Audience {
		if _, ok := v.audiences[aud]; ok {
			audOK = true
			break
		}
	}
	if !audOK {
		return GoogleClaims{}, ErrInvalidOAuthToken
	}

	var claims struct {
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
		Name          string `json:"name"`
	}
	if err := token.Claims(&claims); err != nil {
		return GoogleClaims{}, ErrInvalidOAuthToken
	}
	if !claims.EmailVerified {
		return GoogleClaims{}, ErrEmailNotVerified
	}
	email := NormalizeEmail(claims.Email)
	if email == "" || !ValidEmail(email) {
		return GoogleClaims{}, ErrInvalidOAuthToken
	}

	var name *string
	if n := strings.TrimSpace(claims.Name); n != "" {
		name = &n
	}

	return GoogleClaims{
		Sub:           token.Subject,
		Email:         email,
		EmailVerified: true,
		Name:          name,
	}, nil
}
