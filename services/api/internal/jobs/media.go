package jobs

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type MediaFile struct {
	ID               string     `json:"id"`
	WorkspaceID      string     `json:"workspace_id"`
	ItemID           string     `json:"item_id"`
	Role             string     `json:"role"`
	StorageKey       string     `json:"storage_key,omitempty"`
	MimeType         string     `json:"mime_type"`
	Width            *int       `json:"width,omitempty"`
	Height           *int       `json:"height,omitempty"`
	DurationMs       *int       `json:"duration_ms,omitempty"`
	SizeBytes        int64      `json:"size_bytes"`
	OriginalFilename *string    `json:"original_filename,omitempty"`
	Status           string     `json:"status"`
	ETag             *string    `json:"etag,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
	DeletedAt        *time.Time `json:"deleted_at,omitempty"`
}

type CreateMediaInput struct {
	ID               string
	Role             string
	MimeType         string
	SizeBytes        int64
	OriginalFilename *string
	Width            *int
	Height           *int
	DurationMs       *int
}

type CreateMediaResult struct {
	MediaFileID   string    `json:"media_file_id"`
	UploadURL     string    `json:"upload_url"`
	StorageKey    string    `json:"storage_key"`
	ExpiresAt     time.Time `json:"expires_at"`
	MaxSizeBytes  int64     `json:"max_size_bytes"`
	AllowedMimes  []string  `json:"allowed_mimes"`
}

type CompleteMediaInput struct {
	ETag      string
	SizeBytes int64
}

func (s *Service) listMediaFiles(ctx context.Context, jobID string, since *time.Time) ([]MediaFile, error) {
	q := `
		SELECT m.id, m.workspace_id, m.item_id, m.role, m.storage_key, m.mime_type,
		       m.width, m.height, m.duration_ms, m.size_bytes, m.original_filename,
		       m.status, m.etag, m.created_at, m.updated_at, m.deleted_at
		FROM media_files m
		JOIN items i ON i.id = m.item_id
		WHERE i.job_id = $1
	`
	args := []any{jobID}
	if since != nil {
		q += ` AND m.updated_at >= $2`
		args = append(args, *since)
	} else {
		q += ` AND m.deleted_at IS NULL`
	}
	q += ` ORDER BY m.updated_at DESC`
	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []MediaFile
	for rows.Next() {
		mf, err := scanMediaFile(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, mf)
	}
	if out == nil {
		out = []MediaFile{}
	}
	return out, rows.Err()
}

func (s *Service) CreateMediaUpload(ctx context.Context, userID, itemID string, in CreateMediaInput, presign func(key, mime string) (string, error)) (CreateMediaResult, error) {
	if in.Role == "" || in.MimeType == "" || in.SizeBytes <= 0 {
		return CreateMediaResult{}, errors.New("missing required media fields")
	}
	if in.SizeBytes > MaxBlobBytes {
		return CreateMediaResult{}, errors.New("payload too large")
	}
	if !mimeAllowed(in.MimeType) {
		return CreateMediaResult{}, errors.New("unsupported media")
	}
	if in.DurationMs != nil && *in.DurationMs > MaxVoiceDurationMs {
		return CreateMediaResult{}, errors.New("voice too long")
	}

	item, err := s.fetchItem(ctx, itemID)
	if err != nil {
		return CreateMediaResult{}, err
	}
	if _, err := s.requireJobWrite(ctx, userID, item.JobID); err != nil {
		return CreateMediaResult{}, err
	}

	id := in.ID
	if id == "" {
		id = uuid.NewString()
	}
	key := fmt.Sprintf("%s/%s/%s/%s", item.WorkspaceID, item.JobID, itemID, id)
	now := time.Now().UTC()

	_, err = s.pool.Exec(ctx, `
		INSERT INTO media_files (
			id, workspace_id, item_id, role, storage_key, mime_type,
			width, height, duration_ms, size_bytes, original_filename,
			status, created_at, updated_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'pending',$12,$12)
		ON CONFLICT (id) DO UPDATE SET
			role = EXCLUDED.role,
			mime_type = EXCLUDED.mime_type,
			width = EXCLUDED.width,
			height = EXCLUDED.height,
			duration_ms = EXCLUDED.duration_ms,
			size_bytes = EXCLUDED.size_bytes,
			original_filename = EXCLUDED.original_filename,
			status = 'pending',
			updated_at = EXCLUDED.updated_at,
			deleted_at = NULL
	`, id, item.WorkspaceID, itemID, in.Role, key, in.MimeType,
		in.Width, in.Height, in.DurationMs, in.SizeBytes, in.OriginalFilename, now)
	if err != nil {
		return CreateMediaResult{}, err
	}

	uploadURL, err := presign(key, in.MimeType)
	if err != nil {
		return CreateMediaResult{}, err
	}

	return CreateMediaResult{
		MediaFileID:  id,
		UploadURL:    uploadURL,
		StorageKey:   key,
		ExpiresAt:    now.Add(15 * time.Minute),
		MaxSizeBytes: MaxBlobBytes,
		AllowedMimes: allowedMimeList(in.MimeType),
	}, nil
}

func allowedMimeList(mime string) []string {
	mime = strings.ToLower(strings.TrimSpace(mime))
	if allowedPhotoMimes[mime] || strings.HasPrefix(mime, "image/") {
		out := make([]string, 0, len(allowedPhotoMimes))
		for k := range allowedPhotoMimes {
			out = append(out, k)
		}
		return out
	}
	if allowedVoiceMimes[mime] {
		out := make([]string, 0, len(allowedVoiceMimes))
		for k := range allowedVoiceMimes {
			out = append(out, k)
		}
		return out
	}
	out := make([]string, 0, len(allowedFileMimes)+len(allowedPhotoMimes))
	for k := range allowedFileMimes {
		out = append(out, k)
	}
	for k := range allowedPhotoMimes {
		out = append(out, k)
	}
	return out
}

func (s *Service) CompleteMediaUpload(ctx context.Context, userID, mediaID string, in CompleteMediaInput, head func(key string) (int64, string, []byte, error)) (MediaFile, error) {
	mf, err := s.fetchMediaFile(ctx, mediaID)
	if err != nil {
		return MediaFile{}, err
	}
	item, err := s.fetchItem(ctx, mf.ItemID)
	if err != nil {
		return MediaFile{}, err
	}
	if _, err := s.requireJobWrite(ctx, userID, item.JobID); err != nil {
		return MediaFile{}, err
	}

	size, _, headBytes, err := head(mf.StorageKey)
	if err != nil {
		_, _ = s.pool.Exec(ctx, `UPDATE media_files SET status = 'failed', updated_at = now() WHERE id = $1`, mediaID)
		return MediaFile{}, errors.New("object not found")
	}
	if size > MaxBlobBytes {
		_, _ = s.pool.Exec(ctx, `UPDATE media_files SET status = 'failed', updated_at = now() WHERE id = $1`, mediaID)
		return MediaFile{}, errors.New("payload too large")
	}
	if in.SizeBytes > 0 && in.SizeBytes != size {
		size = in.SizeBytes
	}
	if err := validateMagicBytes(mf.MimeType, headBytes); err != nil {
		_, _ = s.pool.Exec(ctx, `UPDATE media_files SET status = 'failed', updated_at = now() WHERE id = $1`, mediaID)
		return MediaFile{}, errors.New("unsupported media")
	}

	etag := in.ETag
	now := time.Now().UTC()
	_, err = s.pool.Exec(ctx, `
		UPDATE media_files SET
			status = 'uploaded',
			size_bytes = $2,
			etag = $3,
			updated_at = $4
		WHERE id = $1
	`, mediaID, size, nullIfEmpty(etag), now)
	if err != nil {
		return MediaFile{}, err
	}
	// Bump item updated_at so sync clients pick up new/changed media.
	_, _ = s.pool.Exec(ctx, `
		UPDATE items SET updated_at = $2
		WHERE id = $1
	`, mf.ItemID, now)
	_, _ = s.pool.Exec(ctx, `
		UPDATE jobs SET last_activity_at = $2 WHERE id = $1
	`, item.JobID, now)

	return s.fetchMediaFile(ctx, mediaID)
}

func (s *Service) DeleteMedia(ctx context.Context, userID, mediaID string) error {
	mf, err := s.fetchMediaFile(ctx, mediaID)
	if err != nil {
		return err
	}
	if mf.DeletedAt != nil {
		return nil
	}
	item, err := s.fetchItem(ctx, mf.ItemID)
	if err != nil {
		return err
	}
	if _, err := s.requireJobWrite(ctx, userID, item.JobID); err != nil {
		return err
	}
	now := time.Now().UTC()
	_, err = s.pool.Exec(ctx, `
		UPDATE media_files SET deleted_at = $2, updated_at = $2
		WHERE id = $1 AND deleted_at IS NULL
	`, mediaID, now)
	if err != nil {
		return err
	}
	_, _ = s.pool.Exec(ctx, `UPDATE items SET updated_at = $2 WHERE id = $1`, mf.ItemID, now)
	_, _ = s.pool.Exec(ctx, `UPDATE jobs SET last_activity_at = $2 WHERE id = $1`, item.JobID, now)
	return nil
}

func (s *Service) GetMediaForDownload(ctx context.Context, userID, mediaID string) (MediaFile, error) {
	mf, err := s.fetchMediaFile(ctx, mediaID)
	if err != nil {
		return MediaFile{}, err
	}
	if mf.Status != "uploaded" || mf.DeletedAt != nil {
		return MediaFile{}, errors.New("not available")
	}
	item, err := s.fetchItem(ctx, mf.ItemID)
	if err != nil {
		return MediaFile{}, err
	}
	if _, _, err := s.getJobAccess(ctx, userID, item.JobID); err != nil {
		return MediaFile{}, err
	}
	return mf, nil
}

func (s *Service) GetItemPrimaryMedia(ctx context.Context, userID, itemID string) (MediaFile, error) {
	item, err := s.fetchItem(ctx, itemID)
	if err != nil {
		return MediaFile{}, err
	}
	if _, _, err := s.getJobAccess(ctx, userID, item.JobID); err != nil {
		return MediaFile{}, err
	}
	row := s.pool.QueryRow(ctx, `
		SELECT id, workspace_id, item_id, role, storage_key, mime_type,
		       width, height, duration_ms, size_bytes, original_filename,
		       status, etag, created_at, updated_at, deleted_at
		FROM media_files
		WHERE item_id = $1 AND deleted_at IS NULL AND status = 'uploaded'
		  AND role IN ('annotated_render', 'primary_photo', 'file')
		ORDER BY CASE role
		           WHEN 'annotated_render' THEN 0
		           WHEN 'primary_photo' THEN 1
		           ELSE 2
		         END,
		         updated_at DESC
		LIMIT 1
	`, itemID)
	return scanMediaFile(row)
}

func (s *Service) fetchMediaFile(ctx context.Context, id string) (MediaFile, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, workspace_id, item_id, role, storage_key, mime_type,
		       width, height, duration_ms, size_bytes, original_filename,
		       status, etag, created_at, updated_at, deleted_at
		FROM media_files WHERE id = $1
	`, id)
	return scanMediaFile(row)
}

func scanMediaFile(row scannable) (MediaFile, error) {
	var mf MediaFile
	err := row.Scan(
		&mf.ID, &mf.WorkspaceID, &mf.ItemID, &mf.Role, &mf.StorageKey, &mf.MimeType,
		&mf.Width, &mf.Height, &mf.DurationMs, &mf.SizeBytes, &mf.OriginalFilename,
		&mf.Status, &mf.ETag, &mf.CreatedAt, &mf.UpdatedAt, &mf.DeletedAt,
	)
	return mf, err
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

var ErrNotFound = pgx.ErrNoRows
