package billing

import (
	"testing"
	"time"
)

func ptrTime(t time.Time) *time.Time { return &t }

func ptrStr(s string) *string { return &s }

func TestComputeWorkspaceAccess_activeSubscription(t *testing.T) {
	now := time.Date(2026, 6, 12, 12, 0, 0, 0, time.UTC)
	access := ComputeWorkspaceAccess(now, workspaceAccessInput{
		SubscriptionStatus:   "active",
		PaddleSubscriptionID: ptrStr("sub_123"),
	})
	if access.Mode != AccessActive || !access.Writable || !access.SyncPushAllowed {
		t.Fatalf("expected active writable access, got %+v", access)
	}
}

func TestComputeWorkspaceAccess_trial(t *testing.T) {
	now := time.Date(2026, 6, 12, 12, 0, 0, 0, time.UTC)
	started := now.Add(-3 * 24 * time.Hour)
	access := ComputeWorkspaceAccess(now, workspaceAccessInput{
		SubscriptionStatus: "none",
		TrialStartedAt:     &started,
	})
	if access.Mode != AccessTrial || !access.Writable {
		t.Fatalf("expected trial access, got %+v", access)
	}
	if access.TrialJobLimit != TrialJobLimit || access.TrialItemLimit != TrialItemLimit {
		t.Fatalf("expected trial limits, got %+v", access)
	}
}

func TestComputeWorkspaceAccess_gracePeriod(t *testing.T) {
	now := time.Date(2026, 6, 12, 12, 0, 0, 0, time.UTC)
	ended := now.Add(-2 * 24 * time.Hour)
	access := ComputeWorkspaceAccess(now, workspaceAccessInput{
		SubscriptionStatus:    "past_due",
		PaddleSubscriptionID:  ptrStr("sub_123"),
		SubscriptionEndedAt:   &ended,
	})
	if access.Mode != AccessGrace || !access.Writable || !access.SyncPushAllowed {
		t.Fatalf("expected grace access, got %+v", access)
	}
	if access.GraceDaysRemaining <= 0 {
		t.Fatalf("expected grace days remaining, got %+v", access)
	}
}

func TestComputeWorkspaceAccess_readOnlyAfterGrace(t *testing.T) {
	now := time.Date(2026, 6, 12, 12, 0, 0, 0, time.UTC)
	ended := now.Add(-10 * 24 * time.Hour)
	access := ComputeWorkspaceAccess(now, workspaceAccessInput{
		SubscriptionStatus:   "canceled",
		PaddleSubscriptionID: ptrStr("sub_123"),
		SubscriptionEndedAt:  &ended,
	})
	if access.Mode != AccessReadOnly || access.Writable || access.SyncPushAllowed {
		t.Fatalf("expected read-only access, got %+v", access)
	}
}

func TestComputeWorkspaceAccess_trialExpired(t *testing.T) {
	now := time.Date(2026, 6, 12, 12, 0, 0, 0, time.UTC)
	started := now.Add(-20 * 24 * time.Hour)
	access := ComputeWorkspaceAccess(now, workspaceAccessInput{
		SubscriptionStatus: "none",
		TrialStartedAt:     &started,
	})
	if access.Mode != AccessReadOnly || access.Writable {
		t.Fatalf("expected read-only after trial, got %+v", access)
	}
}
