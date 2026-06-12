package billing

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	paddle "github.com/PaddleHQ/paddle-go-sdk"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotOwner              = errors.New("owner required")
	ErrNoSubscription        = errors.New("no active subscription")
	ErrTooManyMembers        = errors.New("too many members for plan")
	ErrBillingNotConfigured  = errors.New("billing not configured")
)

type WorkspaceBilling struct {
	PlanSKU            string  `json:"plan_sku"`
	PlanDisplayName    string  `json:"plan_display_name"`
	MemberLimit        int     `json:"member_limit"`
	SubscriptionStatus string  `json:"subscription_status"`
	HasSubscription    bool    `json:"has_subscription"`
	PaddleCustomerID   *string `json:"paddle_customer_id,omitempty"`
	MemberCount        int     `json:"member_count"`
	PendingInviteCount int     `json:"pending_invite_count"`
	Plans              []Plan  `json:"plans"`
}

type Service struct {
	pool           *pgxpool.Pool
	catalog        []Plan
	webhookSecret  string
	apiKey         string
	apiBaseURL     string
	webhookVerify  *paddle.WebhookVerifier
	httpClient     *http.Client
}

func NewService(pool *pgxpool.Pool, apiKey, webhookSecret, env string, priceIDs map[string]string) *Service {
	baseURL := paddle.ProductionBaseURL
	if strings.EqualFold(strings.TrimSpace(env), "sandbox") {
		baseURL = paddle.SandboxBaseURL
	}
	var verifier *paddle.WebhookVerifier
	if webhookSecret != "" {
		verifier = paddle.NewWebhookVerifier(webhookSecret)
	}
	return &Service{
		pool:          pool,
		catalog:       Catalog(priceIDs),
		webhookSecret: webhookSecret,
		apiKey:        apiKey,
		apiBaseURL:    baseURL,
		webhookVerify: verifier,
		httpClient:    &http.Client{Timeout: 15 * time.Second},
	}
}

func (s *Service) Catalog() []Plan {
	return append([]Plan(nil), s.catalog...)
}

func (s *Service) GetWorkspaceBilling(ctx context.Context, userID, workspaceID string) (WorkspaceBilling, error) {
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return WorkspaceBilling{}, err
	}

	var (
		planSKU            string
		memberLimit        int
		subscriptionStatus string
		paddleCustomerID   *string
		paddleSubscription *string
	)
	err := s.pool.QueryRow(ctx, `
		SELECT plan_sku, member_limit, subscription_status, paddle_customer_id, paddle_subscription_id
		FROM workspaces
		WHERE id = $1
	`, workspaceID).Scan(&planSKU, &memberLimit, &subscriptionStatus, &paddleCustomerID, &paddleSubscription)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return WorkspaceBilling{}, errors.New("workspace not found")
		}
		return WorkspaceBilling{}, err
	}

	var memberCount int
	if err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int
		FROM workspace_memberships
		WHERE workspace_id = $1 AND status = 'active'
	`, workspaceID).Scan(&memberCount); err != nil {
		return WorkspaceBilling{}, err
	}

	var pendingCount int
	if err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int
		FROM workspace_invites
		WHERE workspace_id = $1 AND status = 'pending'
	`, workspaceID).Scan(&pendingCount); err != nil {
		return WorkspaceBilling{}, err
	}

	hasSubscription := paddleSubscription != nil && *paddleSubscription != ""
	return WorkspaceBilling{
		PlanSKU:            planSKU,
		PlanDisplayName:    DisplayNameForSKU(planSKU),
		MemberLimit:        memberLimit,
		SubscriptionStatus: subscriptionStatus,
		HasSubscription:    hasSubscription,
		PaddleCustomerID:   paddleCustomerID,
		MemberCount:        memberCount,
		PendingInviteCount: pendingCount,
		Plans:              s.catalog,
	}, nil
}

func (s *Service) OpenPortal(ctx context.Context, userID, workspaceID string) (string, error) {
	if s.apiKey == "" {
		return "", ErrBillingNotConfigured
	}
	if err := s.requireOwner(ctx, userID, workspaceID); err != nil {
		return "", err
	}

	var customerID, subscriptionID *string
	err := s.pool.QueryRow(ctx, `
		SELECT paddle_customer_id, paddle_subscription_id
		FROM workspaces
		WHERE id = $1
	`, workspaceID).Scan(&customerID, &subscriptionID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", errors.New("workspace not found")
		}
		return "", err
	}
	if customerID == nil || *customerID == "" {
		return "", ErrNoSubscription
	}

	subID := ""
	if subscriptionID != nil {
		subID = *subscriptionID
	}
	return s.CreatePortalSession(ctx, *customerID, subID)
}

func (s *Service) CanDowngradeTo(ctx context.Context, workspaceID, targetSKU string) error {
	plan, ok := PlanBySKU(s.catalog, targetSKU)
	if !ok {
		return fmt.Errorf("unknown plan sku")
	}
	var memberCount int
	if err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int
		FROM workspace_memberships
		WHERE workspace_id = $1 AND status = 'active'
	`, workspaceID).Scan(&memberCount); err != nil {
		return err
	}
	if memberCount > plan.MemberLimit {
		return ErrTooManyMembers
	}
	return nil
}

func (s *Service) WorkspaceWritable(ctx context.Context, workspaceID string) (bool, error) {
	var status string
	var paddleSubscription *string
	err := s.pool.QueryRow(ctx, `
		SELECT subscription_status, paddle_subscription_id
		FROM workspaces
		WHERE id = $1
	`, workspaceID).Scan(&status, &paddleSubscription)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, errors.New("workspace not found")
		}
		return false, err
	}
	return WorkspaceWritable(status, paddleSubscription), nil
}

func (s *Service) requireOwner(ctx context.Context, userID, workspaceID string) error {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, userID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("not a workspace member")
		}
		return err
	}
	if role != "owner" {
		return ErrNotOwner
	}
	return nil
}
