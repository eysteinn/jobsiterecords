CREATE TABLE job_assignments (
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by_user_id UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    PRIMARY KEY (job_id, user_id)
);

CREATE INDEX job_assignments_user_idx ON job_assignments(user_id) WHERE revoked_at IS NULL;

-- Backfill: creator of each job is assigned (matches UpsertJob on create).
INSERT INTO job_assignments (job_id, user_id, assigned_by_user_id, assigned_at)
SELECT j.id, j.created_by_user_id, j.created_by_user_id, j.created_at
FROM jobs j
ON CONFLICT (job_id, user_id) DO NOTHING;
