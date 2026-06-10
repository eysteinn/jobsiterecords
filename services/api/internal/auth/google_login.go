package auth

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

func (s *Service) LoginWithGoogle(ctx context.Context, idToken string, deviceLabel *string) (User, SessionPair, error) {
	if s.google == nil {
		return User{}, SessionPair{}, ErrOAuthNotConfigured
	}
	claims, err := s.google.Verify(ctx, idToken)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, SessionPair{}, err
	}
	defer tx.Rollback(ctx)

	userID, user, err := s.resolveGoogleUser(ctx, tx, claims)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	if err := s.ensureDefaultWorkspaceTx(ctx, tx, userID, user.Name, user.Email); err != nil {
		return User{}, SessionPair{}, err
	}

	session, err := s.createSessionTx(ctx, tx, userID, deviceLabel)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return User{}, SessionPair{}, err
	}
	return user, session, nil
}

func (s *Service) resolveGoogleUser(ctx context.Context, tx pgx.Tx, claims GoogleClaims) (string, User, error) {
	var userID string
	err := tx.QueryRow(ctx, `
		SELECT user_id FROM user_oauth_identities
		WHERE provider = 'google' AND provider_subject = $1
	`, claims.Sub).Scan(&userID)
	if err == nil {
		var user User
		err = tx.QueryRow(ctx, `
			SELECT id, email, name, created_at FROM users WHERE id = $1
		`, userID).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
		return userID, user, err
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", User{}, err
	}

	var user User
	err = tx.QueryRow(ctx, `
		SELECT id, email, name, created_at FROM users WHERE email = $1
	`, claims.Email).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err == nil {
		if err := s.linkGoogleIdentity(ctx, tx, user.ID, claims); err != nil {
			if isUniqueViolation(err) {
				return s.resolveGoogleUser(ctx, tx, claims)
			}
			return "", User{}, err
		}
		if user.Name == nil && claims.Name != nil {
			_, _ = tx.Exec(ctx, `
				UPDATE users SET name = $1 WHERE id = $2 AND name IS NULL
			`, *claims.Name, user.ID)
			user.Name = claims.Name
		}
		return user.ID, user, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", User{}, err
	}

	err = tx.QueryRow(ctx, `
		INSERT INTO users (email, name) VALUES ($1, $2)
		RETURNING id, email, name, created_at
	`, claims.Email, claims.Name).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err != nil {
		return "", User{}, err
	}

	if err := s.linkGoogleIdentity(ctx, tx, user.ID, claims); err != nil {
		return "", User{}, err
	}

	wsName := defaultWorkspaceName(claims.Name, claims.Email)
	var workspaceID string
	err = tx.QueryRow(ctx, `
		INSERT INTO workspaces (name, owner_user_id, plan_sku, member_limit)
		VALUES ($1, $2, 'crew_5', 5) RETURNING id
	`, wsName, user.ID).Scan(&workspaceID)
	if err != nil {
		return "", User{}, err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO workspace_memberships (workspace_id, user_id, role, status)
		VALUES ($1, $2, 'owner', 'active')
	`, workspaceID, user.ID)
	if err != nil {
		return "", User{}, err
	}

	return user.ID, user, nil
}

func (s *Service) linkGoogleIdentity(ctx context.Context, tx pgx.Tx, userID string, claims GoogleClaims) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO user_oauth_identities (user_id, provider, provider_subject)
		VALUES ($1, 'google', $2)
	`, userID, claims.Sub)
	return err
}

func (s *Service) ensureDefaultWorkspaceTx(ctx context.Context, tx pgx.Tx, userID string, name *string, email string) error {
	hasWS, err := s.userHasActiveWorkspace(ctx, tx, userID)
	if err != nil {
		return err
	}
	if hasWS {
		return nil
	}
	wsName := defaultWorkspaceName(name, email)
	var workspaceID string
	err = tx.QueryRow(ctx, `
		INSERT INTO workspaces (name, owner_user_id, plan_sku, member_limit)
		VALUES ($1, $2, 'crew_5', 5) RETURNING id
	`, wsName, userID).Scan(&workspaceID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO workspace_memberships (workspace_id, user_id, role, status)
		VALUES ($1, $2, 'owner', 'active')
	`, workspaceID, userID)
	return err
}
