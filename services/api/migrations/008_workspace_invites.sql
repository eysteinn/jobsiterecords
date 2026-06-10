-- M5: workspace invites for team collaboration

CREATE TABLE workspace_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member')),
    invited_by_user_id UUID NOT NULL REFERENCES users(id),
    token_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    accepted_by_user_id UUID REFERENCES users(id)
);

CREATE UNIQUE INDEX workspace_invites_pending_email_idx
    ON workspace_invites (workspace_id, lower(email))
    WHERE status = 'pending';

CREATE INDEX workspace_invites_workspace_idx ON workspace_invites(workspace_id);

-- Until billing ships, default new and existing solo workspaces to crew_5 so invites are testable.
UPDATE workspaces
SET plan_sku = 'crew_5', member_limit = 5
WHERE plan_sku = 'solo_1' AND member_limit = 1;
