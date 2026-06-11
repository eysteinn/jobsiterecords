CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    job_id UUID NOT NULL REFERENCES jobs(id),
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    date_from DATE,
    date_to DATE,
    include_photos BOOLEAN NOT NULL DEFAULT true,
    include_notes BOOLEAN NOT NULL DEFAULT true,
    include_voice BOOLEAN NOT NULL DEFAULT true,
    include_files BOOLEAN NOT NULL DEFAULT true,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'rendering', 'ready', 'failed')),
    storage_key TEXT,
    size_bytes BIGINT,
    page_count INT,
    error_msg TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX reports_workspace_created ON reports(workspace_id, created_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX reports_job ON reports(job_id)
    WHERE deleted_at IS NULL;
