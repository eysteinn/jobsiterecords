package workspace

import (
	"context"
	"errors"
	"time"

	"github.com/eysteinn/jobsiterecords/services/api/internal/billing"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Workspace struct {
	ID                 string    `json:"id"`
	Name               string    `json:"name"`
	Role               string    `json:"role"`
	PlanSKU            string    `json:"plan_sku"`
	MemberLimit        int       `json:"member_limit"`
	SubscriptionStatus string    `json:"subscription_status"`
	HasSubscription    bool      `json:"has_subscription"`
	CreatedAt          time.Time `json:"created_at"`
	AccessMode         string    `json:"access_mode"`
	Writable           bool      `json:"writable"`
	SyncPushAllowed    bool      `json:"sync_push_allowed"`
	TrialEndsAt        *time.Time `json:"trial_ends_at,omitempty"`
	GraceEndsAt        *time.Time `json:"grace_ends_at,omitempty"`
	GraceDaysRemaining int       `json:"grace_days_remaining,omitempty"`
	TrialJobLimit      int       `json:"trial_job_limit,omitempty"`
	TrialItemLimit     int       `json:"trial_item_limit,omitempty"`
}

type accessProvider interface {
	GetWorkspaceAccess(ctx context.Context, workspaceID string) (billing.WorkspaceAccess, error)
}

type Service struct {
	pool    *pgxpool.Pool
	billing accessProvider
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

func (s *Service) SetBilling(b accessProvider) {
	s.billing = b
}

func (s *Service) ListForUser(ctx context.Context, userID string) ([]Workspace, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT w.id, w.name, m.role, w.plan_sku, w.member_limit, w.subscription_status,
		       (w.paddle_subscription_id IS NOT NULL), w.created_at
		FROM workspace_memberships m
		JOIN workspaces w ON w.id = m.workspace_id
		WHERE m.user_id = $1 AND m.status = 'active'
		ORDER BY w.name
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Workspace
	for rows.Next() {
		var ws Workspace
		if err := rows.Scan(
			&ws.ID, &ws.Name, &ws.Role, &ws.PlanSKU, &ws.MemberLimit,
			&ws.SubscriptionStatus, &ws.HasSubscription, &ws.CreatedAt,
		); err != nil {
			return nil, err
		}
		s.applyAccess(ctx, &ws)
		out = append(out, ws)
	}
	return out, rows.Err()
}

func (s *Service) applyAccess(ctx context.Context, ws *Workspace) {
	if s.billing == nil {
		ws.AccessMode = string(billing.AccessActive)
		ws.Writable = true
		ws.SyncPushAllowed = true
		return
	}
	access, err := s.billing.GetWorkspaceAccess(ctx, ws.ID)
	if err != nil {
		ws.AccessMode = string(billing.AccessReadOnly)
		return
	}
	ws.AccessMode = string(access.Mode)
	ws.Writable = access.Writable
	ws.SyncPushAllowed = access.SyncPushAllowed
	ws.TrialEndsAt = access.TrialEndsAt
	ws.GraceEndsAt = access.GraceEndsAt
	ws.GraceDaysRemaining = access.GraceDaysRemaining
	ws.TrialJobLimit = access.TrialJobLimit
	ws.TrialItemLimit = access.TrialItemLimit
}

func (s *Service) Leave(ctx context.Context, userID, workspaceID string) error {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, userID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("not a member of this workspace")
		}
		return err
	}
	if role == "owner" {
		return errors.New("owner must transfer ownership or delete workspace before leaving")
	}
	_, err = s.pool.Exec(ctx, `
		UPDATE workspace_memberships
		SET status = 'left', last_active_at = now()
		WHERE workspace_id = $1 AND user_id = $2
	`, workspaceID, userID)
	return err
}
