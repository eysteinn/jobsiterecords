package billing

import "time"

const (
	TrialDays          = 14
	GraceDays          = 7
	ReadOnlyWindowDays = 30
	TrialJobLimit      = 3
	TrialItemLimit     = 50
)

// AccessMode describes how a workspace may be used.
type AccessMode string

const (
	AccessActive   AccessMode = "active"
	AccessTrial    AccessMode = "trial"
	AccessGrace    AccessMode = "grace"
	AccessReadOnly AccessMode = "read_only"
)

// WorkspaceAccess is the computed entitlement for a workspace.
type WorkspaceAccess struct {
	Mode               AccessMode `json:"access_mode"`
	Writable           bool       `json:"writable"`
	SyncPushAllowed    bool       `json:"sync_push_allowed"`
	TrialEndsAt        *time.Time `json:"trial_ends_at,omitempty"`
	GraceEndsAt        *time.Time `json:"grace_ends_at,omitempty"`
	GraceDaysRemaining int        `json:"grace_days_remaining,omitempty"`
	TrialJobLimit      int        `json:"trial_job_limit,omitempty"`
	TrialItemLimit     int        `json:"trial_item_limit,omitempty"`
}

type workspaceAccessInput struct {
	SubscriptionStatus     string
	PaddleSubscriptionID   *string
	TrialStartedAt         *time.Time
	SubscriptionEndedAt    *time.Time
	SubscriptionPastDueAt  *time.Time
}

func hasPaidSubscription(status string, paddleSubscriptionID *string) bool {
	if paddleSubscriptionID == nil || *paddleSubscriptionID == "" {
		return false
	}
	switch status {
	case "active", "trialing":
		return true
	default:
		return false
	}
}

func subscriptionEndedAt(in workspaceAccessInput) *time.Time {
	if in.SubscriptionEndedAt != nil {
		return in.SubscriptionEndedAt
	}
	if in.SubscriptionPastDueAt != nil &&
		(in.SubscriptionStatus == "past_due" || in.SubscriptionStatus == "canceled") {
		return in.SubscriptionPastDueAt
	}
	return nil
}

func trialEndsAt(started *time.Time) *time.Time {
	if started == nil {
		return nil
	}
	end := started.Add(TrialDays * 24 * time.Hour)
	return &end
}

func inTrial(now time.Time, started *time.Time) bool {
	end := trialEndsAt(started)
	if end == nil {
		return false
	}
	return now.Before(*end)
}

// ComputeWorkspaceAccess derives client-visible access from workspace billing fields.
func ComputeWorkspaceAccess(now time.Time, in workspaceAccessInput) WorkspaceAccess {
	if hasPaidSubscription(in.SubscriptionStatus, in.PaddleSubscriptionID) {
		return WorkspaceAccess{
			Mode:            AccessActive,
			Writable:        true,
			SyncPushAllowed: true,
		}
	}

	if ended := subscriptionEndedAt(in); ended != nil {
		graceEnds := ended.Add(GraceDays * 24 * time.Hour)
		if now.Before(graceEnds) {
			daysLeft := int(graceEnds.Sub(now).Hours()/24) + 1
			if daysLeft < 0 {
				daysLeft = 0
			}
			if daysLeft > GraceDays {
				daysLeft = GraceDays
			}
			return WorkspaceAccess{
				Mode:               AccessGrace,
				Writable:           true,
				SyncPushAllowed:    true,
				GraceEndsAt:        &graceEnds,
				GraceDaysRemaining: daysLeft,
			}
		}
		return WorkspaceAccess{
			Mode:            AccessReadOnly,
			Writable:        false,
			SyncPushAllowed: false,
		}
	}

	if inTrial(now, in.TrialStartedAt) {
		end := trialEndsAt(in.TrialStartedAt)
		return WorkspaceAccess{
			Mode:            AccessTrial,
			Writable:        true,
			SyncPushAllowed: true,
			TrialEndsAt:     end,
			TrialJobLimit:   TrialJobLimit,
			TrialItemLimit:  TrialItemLimit,
		}
	}

	return WorkspaceAccess{
		Mode:            AccessReadOnly,
		Writable:        false,
		SyncPushAllowed: false,
	}
}

// WorkspaceWritable reports whether mutations are allowed for a workspace.
func WorkspaceWritable(now time.Time, in workspaceAccessInput) bool {
	return ComputeWorkspaceAccess(now, in).Writable
}
