-- Trial window and subscription lapse tracking for workspace access control.

ALTER TABLE workspaces
    ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS subscription_ended_at TIMESTAMPTZ;

-- Existing workspaces without a paid subscription get a trial window from creation.
UPDATE workspaces
SET trial_started_at = created_at
WHERE trial_started_at IS NULL
  AND (paddle_subscription_id IS NULL OR subscription_status NOT IN ('active', 'trialing'));

-- Lapsed paying workspaces: anchor end time from past_due timestamp when missing.
UPDATE workspaces
SET subscription_ended_at = subscription_past_due_at
WHERE subscription_ended_at IS NULL
  AND subscription_past_due_at IS NOT NULL
  AND subscription_status IN ('past_due', 'canceled');
