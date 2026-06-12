-- Paddle billing: webhook idempotency + workspace subscription state.

CREATE TABLE paddle_events (
    paddle_event_id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    workspace_id UUID REFERENCES workspaces(id) ON DELETE SET NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    payload JSONB NOT NULL
);

CREATE INDEX paddle_events_workspace_id_idx ON paddle_events(workspace_id);

ALTER TABLE workspaces
    ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'none'
        CHECK (subscription_status IN ('none', 'active', 'past_due', 'canceled', 'trialing')),
    ADD COLUMN IF NOT EXISTS subscription_past_due_at TIMESTAMPTZ;

-- Workspaces with an existing Paddle subscription id are treated as active until webhooks refine status.
UPDATE workspaces
SET subscription_status = 'active'
WHERE paddle_subscription_id IS NOT NULL AND subscription_status = 'none';
