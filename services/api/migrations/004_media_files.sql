CREATE TABLE media_files (
    id UUID PRIMARY KEY,
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('primary_photo', 'voice_note', 'attachment', 'file')),
    storage_key TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    width INT,
    height INT,
    duration_ms INT,
    size_bytes BIGINT NOT NULL,
    original_filename TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'uploaded', 'failed')),
    etag TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX media_files_item_idx ON media_files(item_id) WHERE deleted_at IS NULL;
CREATE INDEX media_files_workspace_updated_idx ON media_files(workspace_id, updated_at DESC);
