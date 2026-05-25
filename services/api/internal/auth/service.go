package auth

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type User struct {
	ID        string  `json:"id"`
	Email     string  `json:"email"`
	Name      *string `json:"name,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type SessionPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	SessionID    string `json:"session_id"`
}

type Service struct {
	pool   *pgxpool.Pool
	secret string
	accessTTL time.Duration
	refreshDays int
	magicMinutes int
	resetMinutes int
}

func NewService(pool *pgxpool.Pool, secret string, accessMinutes, refreshDays, magicMinutes, resetMinutes int) *Service {
	return &Service{
		pool: pool,
		secret: secret,
		accessTTL: time.Duration(accessMinutes) * time.Minute,
		refreshDays: refreshDays,
		magicMinutes: magicMinutes,
		resetMinutes: resetMinutes,
	}
}

func (s *Service) SignUp(ctx context.Context, email, password string, name *string) (User, SessionPair, error) {
	email = NormalizeEmail(email)
	hash, err := HashPassword(password)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, SessionPair{}, err
	}
	defer tx.Rollback(ctx)

	var user User
	err = tx.QueryRow(ctx, `
		INSERT INTO users (email, name, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, email, name, created_at
	`, email, name, hash).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return User{}, SessionPair{}, errors.New("email already registered")
		}
		return User{}, SessionPair{}, err
	}

	wsName := defaultWorkspaceName(name, email)
	var workspaceID string
	err = tx.QueryRow(ctx, `
		INSERT INTO workspaces (name, owner_user_id, plan_sku, member_limit)
		VALUES ($1, $2, 'solo_1', 1)
		RETURNING id
	`, wsName, user.ID).Scan(&workspaceID)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO workspace_memberships (workspace_id, user_id, role, status)
		VALUES ($1, $2, 'owner', 'active')
	`, workspaceID, user.ID)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	session, err := s.createSessionTx(ctx, tx, user.ID, nil)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return User{}, SessionPair{}, err
	}
	return user, session, nil
}

func (s *Service) Login(ctx context.Context, email, password string, deviceLabel *string) (User, SessionPair, error) {
	email = NormalizeEmail(email)
	var user User
	var hash *string
	err := s.pool.QueryRow(ctx, `
		SELECT id, email, name, password_hash, created_at
		FROM users WHERE email = $1
	`, email).Scan(&user.ID, &user.Email, &user.Name, &hash, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return User{}, SessionPair{}, ErrInvalidPassword
		}
		return User{}, SessionPair{}, err
	}
	if hash == nil || !VerifyPassword(*hash, password) {
		return User{}, SessionPair{}, ErrInvalidPassword
	}
	session, err := s.createSession(ctx, user.ID, deviceLabel)
	if err != nil {
		return User{}, SessionPair{}, err
	}
	return user, session, nil
}

func (s *Service) Refresh(ctx context.Context, refreshPlain string) (User, SessionPair, error) {
	hash := HashToken(refreshPlain)
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, SessionPair{}, err
	}
	defer tx.Rollback(ctx)

	var sessionID, userID string
	var revokedAt *time.Time
	var expiresAt time.Time
	err = tx.QueryRow(ctx, `
		SELECT id, user_id, revoked_at, expires_at
		FROM auth_refresh_tokens
		WHERE token_hash = $1
		FOR UPDATE
	`, hash).Scan(&sessionID, &userID, &revokedAt, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return User{}, SessionPair{}, errors.New("invalid refresh token")
		}
		return User{}, SessionPair{}, err
	}

	if revokedAt != nil {
		// Reuse detection: revoke all sessions for user
		_, _ = tx.Exec(ctx, `UPDATE auth_refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, userID)
		return User{}, SessionPair{}, errors.New("refresh token reuse detected")
	}
	if time.Now().After(expiresAt) {
		return User{}, SessionPair{}, errors.New("refresh token expired")
	}

	_, err = tx.Exec(ctx, `UPDATE auth_refresh_tokens SET revoked_at = now() WHERE id = $1`, sessionID)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	session, err := s.createSessionTx(ctx, tx, userID, nil)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	var user User
	err = tx.QueryRow(ctx, `SELECT id, email, name, created_at FROM users WHERE id = $1`, userID).
		Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return User{}, SessionPair{}, err
	}
	return user, session, nil
}

func (s *Service) Logout(ctx context.Context, sessionID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE auth_refresh_tokens SET revoked_at = now()
		WHERE id = $1 AND revoked_at IS NULL
	`, sessionID)
	return err
}

func (s *Service) GetUser(ctx context.Context, userID string) (User, error) {
	var user User
	err := s.pool.QueryRow(ctx, `
		SELECT id, email, name, created_at FROM users WHERE id = $1
	`, userID).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	return user, err
}

func (s *Service) CreateMagicLink(ctx context.Context, email string) (plain string, err error) {
	email = NormalizeEmail(email)
	userID, err := s.ensureUser(ctx, email)
	if err != nil {
		return "", err
	}
	plain, hash, err := NewOpaqueToken()
	if err != nil {
		return "", err
	}
	expires := time.Now().Add(time.Duration(s.magicMinutes) * time.Minute)
	_, err = s.pool.Exec(ctx, `
		INSERT INTO auth_one_time_tokens (user_id, email, token_hash, kind, expires_at)
		VALUES ($1, $2, $3, 'magic_link', $4)
	`, userID, email, hash, expires)
	return plain, err
}

func (s *Service) VerifyMagicLink(ctx context.Context, plain string, deviceLabel *string) (User, SessionPair, error) {
	hash := HashToken(plain)
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return User{}, SessionPair{}, err
	}
	defer tx.Rollback(ctx)

	var tokenID, userID, email string
	var usedAt *time.Time
	var expiresAt time.Time
	err = tx.QueryRow(ctx, `
		SELECT id, user_id, email, used_at, expires_at
		FROM auth_one_time_tokens
		WHERE token_hash = $1 AND kind = 'magic_link'
		FOR UPDATE
	`, hash).Scan(&tokenID, &userID, &email, &usedAt, &expiresAt)
	if err != nil {
		return User{}, SessionPair{}, errors.New("invalid or expired link")
	}
	if usedAt != nil || time.Now().After(expiresAt) {
		return User{}, SessionPair{}, errors.New("invalid or expired link")
	}

	_, err = tx.Exec(ctx, `UPDATE auth_one_time_tokens SET used_at = now() WHERE id = $1`, tokenID)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	// Magic-link-only users get a workspace on first verify if they have none
	hasWS, err := s.userHasActiveWorkspace(ctx, tx, userID)
	if err != nil {
		return User{}, SessionPair{}, err
	}
	if !hasWS {
		wsName := defaultWorkspaceName(nil, email)
		var workspaceID string
		err = tx.QueryRow(ctx, `
			INSERT INTO workspaces (name, owner_user_id, plan_sku, member_limit)
			VALUES ($1, $2, 'solo_1', 1) RETURNING id
		`, wsName, userID).Scan(&workspaceID)
		if err != nil {
			return User{}, SessionPair{}, err
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO workspace_memberships (workspace_id, user_id, role, status)
			VALUES ($1, $2, 'owner', 'active')
		`, workspaceID, userID)
		if err != nil {
			return User{}, SessionPair{}, err
		}
	}

	session, err := s.createSessionTx(ctx, tx, userID, deviceLabel)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	var user User
	err = tx.QueryRow(ctx, `SELECT id, email, name, created_at FROM users WHERE id = $1`, userID).
		Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err != nil {
		return User{}, SessionPair{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return User{}, SessionPair{}, err
	}
	return user, session, nil
}

func (s *Service) CreatePasswordReset(ctx context.Context, email string) (plain string, err error) {
	email = NormalizeEmail(email)
	var userID string
	err = s.pool.QueryRow(ctx, `SELECT id FROM users WHERE email = $1`, email).Scan(&userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Don't reveal whether email exists
			return "", nil
		}
		return "", err
	}
	plain, hash, err := NewOpaqueToken()
	if err != nil {
		return "", err
	}
	expires := time.Now().Add(time.Duration(s.resetMinutes) * time.Minute)
	_, err = s.pool.Exec(ctx, `
		INSERT INTO auth_one_time_tokens (user_id, email, token_hash, kind, expires_at)
		VALUES ($1, $2, $3, 'password_reset', $4)
	`, userID, email, hash, expires)
	return plain, err
}

func (s *Service) ResetPassword(ctx context.Context, plain, newPassword string) error {
	hash := HashToken(plain)
	newHash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var tokenID, userID string
	var usedAt *time.Time
	var expiresAt time.Time
	err = tx.QueryRow(ctx, `
		SELECT id, user_id, used_at, expires_at
		FROM auth_one_time_tokens
		WHERE token_hash = $1 AND kind = 'password_reset'
		FOR UPDATE
	`, hash).Scan(&tokenID, &userID, &usedAt, &expiresAt)
	if err != nil {
		return errors.New("invalid or expired reset link")
	}
	if usedAt != nil || time.Now().After(expiresAt) {
		return errors.New("invalid or expired reset link")
	}

	_, err = tx.Exec(ctx, `UPDATE auth_one_time_tokens SET used_at = now() WHERE id = $1`, tokenID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `UPDATE users SET password_hash = $1 WHERE id = $2`, newHash, userID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		UPDATE auth_refresh_tokens SET revoked_at = now()
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Service) createSession(ctx context.Context, userID string, deviceLabel *string) (SessionPair, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return SessionPair{}, err
	}
	defer tx.Rollback(ctx)
	session, err := s.createSessionTx(ctx, tx, userID, deviceLabel)
	if err != nil {
		return SessionPair{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return SessionPair{}, err
	}
	return session, nil
}

func (s *Service) createSessionTx(ctx context.Context, tx pgx.Tx, userID string, deviceLabel *string) (SessionPair, error) {
	plain, hash, err := NewOpaqueToken()
	if err != nil {
		return SessionPair{}, err
	}
	sessionID := uuid.NewString()
	expires := time.Now().Add(time.Duration(s.refreshDays) * 24 * time.Hour)
	_, err = tx.Exec(ctx, `
		INSERT INTO auth_refresh_tokens (id, user_id, token_hash, device_label, expires_at)
		VALUES ($1, $2, $3, $4, $5)
	`, sessionID, userID, hash, deviceLabel, expires)
	if err != nil {
		return SessionPair{}, err
	}
	access, err := SignAccessToken(s.secret, userID, sessionID, s.accessTTL)
	if err != nil {
		return SessionPair{}, err
	}
	return SessionPair{
		AccessToken:  access,
		RefreshToken: plain,
		SessionID:    sessionID,
	}, nil
}

func (s *Service) ensureUser(ctx context.Context, email string) (string, error) {
	var id string
	err := s.pool.QueryRow(ctx, `SELECT id FROM users WHERE email = $1`, email).Scan(&id)
	if err == nil {
		return id, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}
	err = s.pool.QueryRow(ctx, `
		INSERT INTO users (email) VALUES ($1) RETURNING id
	`, email).Scan(&id)
	return id, err
}

func (s *Service) userHasActiveWorkspace(ctx context.Context, tx pgx.Tx, userID string) (bool, error) {
	var exists bool
	err := tx.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM workspace_memberships
			WHERE user_id = $1 AND status = 'active'
		)
	`, userID).Scan(&exists)
	return exists, err
}

func defaultWorkspaceName(name *string, email string) string {
	if name != nil && *name != "" {
		return *name + "'s Workspace"
	}
	local := email
	if at := indexRune(email, '@'); at > 0 {
		local = email[:at]
	}
	return local + "'s Workspace"
}

func indexRune(s string, r rune) int {
	for i, c := range s {
		if c == r {
			return i
		}
	}
	return -1
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
