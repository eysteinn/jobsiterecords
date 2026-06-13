package workspace

import (
	"context"
	"errors"
	"time"

	"github.com/eysteinn/jobsiterecords/services/api/internal/auth"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrNotOwner          = errors.New("owner access required")
	ErrMemberLimit       = errors.New("workspace is at its member limit")
	ErrWorkspaceReadOnly = errors.New("workspace is read-only")
	ErrAlreadyMember    = errors.New("user is already a workspace member")
	ErrInviteNotFound   = errors.New("invite not found")
	ErrInvalidInvite    = errors.New("invalid or expired invite")
	ErrEmailMismatch    = errors.New("invite email does not match signed-in account")
	ErrCannotRemoveSelf = errors.New("cannot remove yourself")
	ErrCannotRemoveOwner = errors.New("cannot remove workspace owner")
)

const inviteDays = 7

type TeamMember struct {
	UserID            string     `json:"user_id"`
	Email             string     `json:"email"`
	Name              *string    `json:"name,omitempty"`
	Role              string     `json:"role"`
	Status            string     `json:"status"`
	AssignedJobCount  int        `json:"assigned_job_count"`
	LastActiveAt      *time.Time `json:"last_active_at,omitempty"`
	JoinedAt          time.Time  `json:"joined_at"`
}

type TeamInvite struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

type TeamSummary struct {
	Members      []TeamMember `json:"members"`
	Invites      []TeamInvite `json:"invites"`
	MemberCount  int          `json:"member_count"`
	MemberLimit  int          `json:"member_limit"`
	PendingCount int          `json:"pending_count"`
}

func (s *Service) requireOwner(ctx context.Context, userID, workspaceID string) error {
	role, err := s.memberRole(ctx, userID, workspaceID)
	if err != nil {
		return err
	}
	if role != "owner" {
		return ErrNotOwner
	}
	return nil
}

func (s *Service) memberRole(ctx context.Context, userID, workspaceID string) (string, error) {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, userID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", errors.New("not a workspace member")
		}
		return "", err
	}
	return role, nil
}

func (s *Service) GetTeam(ctx context.Context, userID, workspaceID string) (TeamSummary, error) {
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return TeamSummary{}, err
	}
	if err := s.expirePendingInvites(ctx, workspaceID); err != nil {
		return TeamSummary{}, err
	}

	var memberLimit int
	err := s.pool.QueryRow(ctx, `SELECT member_limit FROM workspaces WHERE id = $1`, workspaceID).Scan(&memberLimit)
	if err != nil {
		return TeamSummary{}, err
	}

	memberRows, err := s.pool.Query(ctx, `
		SELECT u.id, u.email, u.name, m.role, m.status, m.last_active_at, m.created_at,
		       COALESCE(ac.cnt, 0)
		FROM workspace_memberships m
		JOIN users u ON u.id = m.user_id
		LEFT JOIN (
			SELECT ja.user_id, COUNT(*)::int AS cnt
			FROM job_assignments ja
			JOIN jobs j ON j.id = ja.job_id
			WHERE j.workspace_id = $1 AND j.deleted_at IS NULL AND ja.revoked_at IS NULL
			GROUP BY ja.user_id
		) ac ON ac.user_id = m.user_id
		WHERE m.workspace_id = $1 AND m.status = 'active'
		ORDER BY
			CASE WHEN m.role = 'owner' THEN 0 ELSE 1 END,
			u.email
	`, workspaceID)
	if err != nil {
		return TeamSummary{}, err
	}
	defer memberRows.Close()

	members := make([]TeamMember, 0)
	for memberRows.Next() {
		var m TeamMember
		if err := memberRows.Scan(
			&m.UserID, &m.Email, &m.Name, &m.Role, &m.Status, &m.LastActiveAt, &m.JoinedAt,
			&m.AssignedJobCount,
		); err != nil {
			return TeamSummary{}, err
		}
		members = append(members, m)
	}
	if err := memberRows.Err(); err != nil {
		return TeamSummary{}, err
	}

	inviteRows, err := s.pool.Query(ctx, `
		SELECT id, email, role, status, created_at, expires_at
		FROM workspace_invites
		WHERE workspace_id = $1 AND status = 'pending' AND expires_at > now()
		ORDER BY created_at DESC
	`, workspaceID)
	if err != nil {
		return TeamSummary{}, err
	}
	defer inviteRows.Close()

	invites := make([]TeamInvite, 0)
	for inviteRows.Next() {
		var inv TeamInvite
		if err := inviteRows.Scan(&inv.ID, &inv.Email, &inv.Role, &inv.Status, &inv.CreatedAt, &inv.ExpiresAt); err != nil {
			return TeamSummary{}, err
		}
		invites = append(invites, inv)
	}
	if err := inviteRows.Err(); err != nil {
		return TeamSummary{}, err
	}

	return TeamSummary{
		Members:      members,
		Invites:      invites,
		MemberCount:  len(members),
		MemberLimit:  memberLimit,
		PendingCount: len(invites),
	}, nil
}

func (s *Service) seatUsage(ctx context.Context, workspaceID string) (active int, pending int, limit int, err error) {
	if err := s.expirePendingInvites(ctx, workspaceID); err != nil {
		return 0, 0, 0, err
	}
	err = s.pool.QueryRow(ctx, `SELECT member_limit FROM workspaces WHERE id = $1`, workspaceID).Scan(&limit)
	if err != nil {
		return 0, 0, 0, err
	}
	err = s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM workspace_memberships
		WHERE workspace_id = $1 AND status = 'active'
	`, workspaceID).Scan(&active)
	if err != nil {
		return 0, 0, 0, err
	}
	err = s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM workspace_invites
		WHERE workspace_id = $1 AND status = 'pending' AND expires_at > now()
	`, workspaceID).Scan(&pending)
	return active, pending, limit, err
}

// expirePendingInvites marks overdue pending invites as expired so they stop reserving seats.
func (s *Service) expirePendingInvites(ctx context.Context, workspaceID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE workspace_invites
		SET status = 'expired'
		WHERE workspace_id = $1 AND status = 'pending' AND expires_at <= now()
	`, workspaceID)
	return err
}

// TouchMemberActivity updates last_active_at for an active workspace member (best-effort).
func (s *Service) TouchMemberActivity(ctx context.Context, userID, workspaceID string) {
	_, _ = s.pool.Exec(ctx, `
		UPDATE workspace_memberships
		SET last_active_at = now()
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, userID)
}

func (s *Service) requireWorkspaceWritable(ctx context.Context, workspaceID string) error {
	if s.billing == nil {
		return nil
	}
	access, err := s.billing.GetWorkspaceAccess(ctx, workspaceID)
	if err != nil {
		return err
	}
	if !access.Writable {
		return ErrWorkspaceReadOnly
	}
	return nil
}

func (s *Service) CreateInvite(ctx context.Context, userID, workspaceID, email string) (TeamInvite, string, error) {
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return TeamInvite{}, "", err
	}
	if err := s.requireWorkspaceWritable(ctx, workspaceID); err != nil {
		return TeamInvite{}, "", err
	}

	email = auth.NormalizeEmail(email)
	if !auth.ValidEmail(email) {
		return TeamInvite{}, "", errors.New("invalid email address")
	}

	active, pending, limit, err := s.seatUsage(ctx, workspaceID)
	if err != nil {
		return TeamInvite{}, "", err
	}
	if active+pending >= limit {
		return TeamInvite{}, "", ErrMemberLimit
	}

	var existingMember bool
	err = s.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM workspace_memberships m
			JOIN users u ON u.id = m.user_id
			WHERE m.workspace_id = $1 AND lower(u.email) = $2 AND m.status = 'active'
		)
	`, workspaceID, email).Scan(&existingMember)
	if err != nil {
		return TeamInvite{}, "", err
	}
	if existingMember {
		return TeamInvite{}, "", ErrAlreadyMember
	}

	plain, hash, err := auth.NewOpaqueToken()
	if err != nil {
		return TeamInvite{}, "", err
	}
	expires := time.Now().Add(inviteDays * 24 * time.Hour)

	var inv TeamInvite
	err = s.pool.QueryRow(ctx, `
		INSERT INTO workspace_invites (workspace_id, email, role, invited_by_user_id, token_hash, expires_at)
		VALUES ($1, $2, 'member', $3, $4, $5)
		RETURNING id, email, role, status, created_at, expires_at
	`, workspaceID, email, userID, hash, expires).Scan(
		&inv.ID, &inv.Email, &inv.Role, &inv.Status, &inv.CreatedAt, &inv.ExpiresAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return TeamInvite{}, "", errors.New("an invite is already pending for this email")
		}
		return TeamInvite{}, "", err
	}
	return inv, plain, nil
}

func (s *Service) ResendInvite(ctx context.Context, userID, workspaceID, inviteID string) (TeamInvite, string, error) {
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return TeamInvite{}, "", err
	}
	if err := s.requireWorkspaceWritable(ctx, workspaceID); err != nil {
		return TeamInvite{}, "", err
	}
	if err := s.expirePendingInvites(ctx, workspaceID); err != nil {
		return TeamInvite{}, "", err
	}

	var priorStatus string
	err := s.pool.QueryRow(ctx, `
		SELECT status FROM workspace_invites
		WHERE id = $1 AND workspace_id = $2
	`, inviteID, workspaceID).Scan(&priorStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return TeamInvite{}, "", ErrInviteNotFound
		}
		return TeamInvite{}, "", err
	}
	if priorStatus == "expired" {
		active, pending, limit, err := s.seatUsage(ctx, workspaceID)
		if err != nil {
			return TeamInvite{}, "", err
		}
		if active+pending >= limit {
			return TeamInvite{}, "", ErrMemberLimit
		}
	}

	plain, hash, err := auth.NewOpaqueToken()
	if err != nil {
		return TeamInvite{}, "", err
	}
	expires := time.Now().Add(inviteDays * 24 * time.Hour)

	var inv TeamInvite
	err = s.pool.QueryRow(ctx, `
		UPDATE workspace_invites
		SET token_hash = $1, expires_at = $2, created_at = now(), status = 'pending'
		WHERE id = $3 AND workspace_id = $4 AND status IN ('pending', 'expired')
		RETURNING id, email, role, status, created_at, expires_at
	`, hash, expires, inviteID, workspaceID).Scan(
		&inv.ID, &inv.Email, &inv.Role, &inv.Status, &inv.CreatedAt, &inv.ExpiresAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return TeamInvite{}, "", ErrInviteNotFound
		}
		return TeamInvite{}, "", err
	}
	return inv, plain, nil
}

func (s *Service) RevokeInvite(ctx context.Context, userID, workspaceID, inviteID string) error {
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return err
	}
	if err := s.requireWorkspaceWritable(ctx, workspaceID); err != nil {
		return err
	}
	tag, err := s.pool.Exec(ctx, `
		UPDATE workspace_invites
		SET status = 'revoked'
		WHERE id = $1 AND workspace_id = $2 AND status = 'pending'
	`, inviteID, workspaceID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrInviteNotFound
	}
	return nil
}

func (s *Service) RemoveMember(ctx context.Context, userID, workspaceID, memberUserID string) error {
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return err
	}
	if userID == memberUserID {
		return ErrCannotRemoveSelf
	}

	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, memberUserID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("member not found")
		}
		return err
	}
	if role == "owner" {
		return ErrCannotRemoveOwner
	}

	_, err = s.pool.Exec(ctx, `
		UPDATE job_assignments ja
		SET revoked_at = now()
		FROM jobs j
		WHERE ja.job_id = j.id
		  AND j.workspace_id = $1
		  AND ja.user_id = $2
		  AND ja.revoked_at IS NULL
	`, workspaceID, memberUserID)
	if err != nil {
		return err
	}

	_, err = s.pool.Exec(ctx, `
		UPDATE workspace_memberships
		SET status = 'removed', last_active_at = now()
		WHERE workspace_id = $1 AND user_id = $2
	`, workspaceID, memberUserID)
	return err
}

type InvitePreview struct {
	WorkspaceID   string `json:"workspace_id"`
	WorkspaceName string `json:"workspace_name"`
	Email         string `json:"email"`
	Role          string `json:"role"`
}

func (s *Service) PreviewInvite(ctx context.Context, plain string) (InvitePreview, error) {
	hash := auth.HashToken(plain)
	var preview InvitePreview
	var status string
	var expiresAt time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT w.id, w.name, i.email, i.role, i.status, i.expires_at
		FROM workspace_invites i
		JOIN workspaces w ON w.id = i.workspace_id
		WHERE i.token_hash = $1
	`, hash).Scan(&preview.WorkspaceID, &preview.WorkspaceName, &preview.Email, &preview.Role, &status, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return InvitePreview{}, ErrInvalidInvite
		}
		return InvitePreview{}, err
	}
	if status != "pending" || time.Now().After(expiresAt) {
		if status == "pending" && time.Now().After(expiresAt) {
			_, _ = s.pool.Exec(ctx, `
				UPDATE workspace_invites SET status = 'expired'
				WHERE token_hash = $1
			`, hash)
		}
		return InvitePreview{}, ErrInvalidInvite
	}
	return preview, nil
}

func (s *Service) AcceptInvite(ctx context.Context, userID, plain string) (Workspace, error) {
	hash := auth.HashToken(plain)

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Workspace{}, err
	}
	defer tx.Rollback(ctx)

	var inviteID, workspaceID, email, role, status string
	var expiresAt time.Time
	err = tx.QueryRow(ctx, `
		SELECT id, workspace_id, email, role, status, expires_at
		FROM workspace_invites
		WHERE token_hash = $1
		FOR UPDATE
	`, hash).Scan(&inviteID, &workspaceID, &email, &role, &status, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Workspace{}, ErrInvalidInvite
		}
		return Workspace{}, err
	}
	if status != "pending" || time.Now().After(expiresAt) {
		if status == "pending" && time.Now().After(expiresAt) {
			_, _ = tx.Exec(ctx, `
				UPDATE workspace_invites SET status = 'expired' WHERE id = $1
			`, inviteID)
		}
		return Workspace{}, ErrInvalidInvite
	}

	_, err = tx.Exec(ctx, `
		UPDATE workspace_invites
		SET status = 'expired'
		WHERE workspace_id = $1 AND status = 'pending' AND expires_at <= now() AND id <> $2
	`, workspaceID, inviteID)
	if err != nil {
		return Workspace{}, err
	}

	var userEmail string
	err = tx.QueryRow(ctx, `SELECT email FROM users WHERE id = $1`, userID).Scan(&userEmail)
	if err != nil {
		return Workspace{}, err
	}
	if auth.NormalizeEmail(userEmail) != auth.NormalizeEmail(email) {
		return Workspace{}, ErrEmailMismatch
	}

	var memberLimit int
	err = tx.QueryRow(ctx, `
		SELECT member_limit FROM workspaces WHERE id = $1
	`, workspaceID).Scan(&memberLimit)
	if err != nil {
		return Workspace{}, err
	}
	var activeCount int
	err = tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM workspace_memberships
		WHERE workspace_id = $1 AND status = 'active'
	`, workspaceID).Scan(&activeCount)
	if err != nil {
		return Workspace{}, err
	}
	if activeCount >= memberLimit {
		return Workspace{}, ErrMemberLimit
	}

	var existingStatus *string
	err = tx.QueryRow(ctx, `
		SELECT status FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2
	`, workspaceID, userID).Scan(&existingStatus)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return Workspace{}, err
	}
	if existingStatus != nil && *existingStatus == "active" {
		_, err = tx.Exec(ctx, `
			UPDATE workspace_invites
			SET status = 'accepted', accepted_at = now(), accepted_by_user_id = $1
			WHERE id = $2
		`, userID, inviteID)
		if err != nil {
			return Workspace{}, err
		}
	} else if existingStatus != nil {
		_, err = tx.Exec(ctx, `
			UPDATE workspace_memberships
			SET role = $1, status = 'active', last_active_at = now()
			WHERE workspace_id = $2 AND user_id = $3
		`, role, workspaceID, userID)
		if err != nil {
			return Workspace{}, err
		}
		_, err = tx.Exec(ctx, `
			UPDATE workspace_invites
			SET status = 'accepted', accepted_at = now(), accepted_by_user_id = $1
			WHERE id = $2
		`, userID, inviteID)
		if err != nil {
			return Workspace{}, err
		}
	} else {
		_, err = tx.Exec(ctx, `
			INSERT INTO workspace_memberships (workspace_id, user_id, role, status, last_active_at)
			VALUES ($1, $2, $3, 'active', now())
		`, workspaceID, userID, role)
		if err != nil {
			return Workspace{}, err
		}
		_, err = tx.Exec(ctx, `
			UPDATE workspace_invites
			SET status = 'accepted', accepted_at = now(), accepted_by_user_id = $1
			WHERE id = $2
		`, userID, inviteID)
		if err != nil {
			return Workspace{}, err
		}
	}

	var ws Workspace
	err = tx.QueryRow(ctx, `
		SELECT w.id, w.name, m.role, w.plan_sku, w.member_limit, w.created_at
		FROM workspaces w
		JOIN workspace_memberships m ON m.workspace_id = w.id AND m.user_id = $1
		WHERE w.id = $2 AND m.status = 'active'
	`, userID, workspaceID).Scan(&ws.ID, &ws.Name, &ws.Role, &ws.PlanSKU, &ws.MemberLimit, &ws.CreatedAt)
	if err != nil {
		return Workspace{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return Workspace{}, err
	}
	return ws, nil
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
