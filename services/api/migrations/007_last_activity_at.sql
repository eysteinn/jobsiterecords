ALTER TABLE jobs ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE jobs j
SET last_activity_at = GREATEST(
    j.updated_at,
    COALESCE((
        SELECT MAX(i.updated_at)
        FROM items i
        WHERE i.job_id = j.id AND i.deleted_at IS NULL
    ), j.updated_at),
    COALESCE((
        SELECT MAX(m.updated_at)
        FROM media_files m
        JOIN items i ON i.id = m.item_id
        WHERE i.job_id = j.id AND m.deleted_at IS NULL
    ), j.updated_at)
);

CREATE INDEX IF NOT EXISTS jobs_workspace_activity_idx
    ON jobs(workspace_id, last_activity_at DESC)
    WHERE deleted_at IS NULL;
