package reports

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"

	"github.com/eysteinn/jobsiterecords/services/api/internal/jobqueue"
)

// PDFReportArgs is the River job payload for PDF generation.
// Defined here so both the handler (to enqueue) and the worker (to process) can import it.
type PDFReportArgs struct {
	ReportID string `json:"report_id"`
}

func (PDFReportArgs) Kind() string { return "pdf_report" }

type Report struct {
	ID              string
	WorkspaceID     string
	JobID           string
	CreatedByUserID string
	Title           string
	DateFrom        *time.Time
	DateTo          *time.Time
	IncludePhotos   bool
	IncludeNotes    bool
	IncludeVoice    bool
	IncludeFiles    bool
	Status          string // queued | rendering | ready | failed
	StorageKey      *string
	SizeBytes       *int64
	PageCount       *int
	ErrorMsg        *string
	CreatedAt       time.Time
	UpdatedAt       time.Time
	DeletedAt       *time.Time
}

type CreateInput struct {
	WorkspaceID     string
	JobID           string
	CreatedByUserID string
	Title           string
	DateFrom        *time.Time
	DateTo          *time.Time
	IncludePhotos   bool
	IncludeNotes    bool
	IncludeVoice    bool
	IncludeFiles    bool
}

type Service struct {
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

// Create inserts a report row and enqueues a River job atomically.
func (s *Service) Create(ctx context.Context, riverClient *river.Client[pgx.Tx], in CreateInput) (Report, error) {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, in.WorkspaceID, in.CreatedByUserID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, errors.New("not a workspace member")
		}
		return Report{}, err
	}

	// Verify job belongs to workspace
	var jobWorkspace string
	err = s.pool.QueryRow(ctx, `
		SELECT workspace_id FROM jobs WHERE id = $1 AND deleted_at IS NULL
	`, in.JobID).Scan(&jobWorkspace)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, errors.New("job not found")
		}
		return Report{}, err
	}
	if jobWorkspace != in.WorkspaceID {
		return Report{}, errors.New("job not in workspace")
	}
	if role == "member" {
		var assigned bool
		err = s.pool.QueryRow(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM job_assignments
				WHERE job_id = $1 AND user_id = $2 AND revoked_at IS NULL
			)
		`, in.JobID, in.CreatedByUserID).Scan(&assigned)
		if err != nil {
			return Report{}, err
		}
		if !assigned {
			return Report{}, errors.New("not assigned to job")
		}
	}

	id := uuid.New().String()

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Report{}, err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO reports (
			id, workspace_id, job_id, created_by_user_id,
			title, date_from, date_to,
			include_photos, include_notes, include_voice, include_files,
			status
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'queued')
	`, id, in.WorkspaceID, in.JobID, in.CreatedByUserID,
		in.Title, in.DateFrom, in.DateTo,
		in.IncludePhotos, in.IncludeNotes, in.IncludeVoice, in.IncludeFiles)
	if err != nil {
		return Report{}, err
	}

	// Enqueue River job in the same transaction so the job and DB row are always consistent.
	if _, err = riverClient.InsertTx(ctx, tx, PDFReportArgs{ReportID: id}, &river.InsertOpts{Queue: jobqueue.Reports}); err != nil {
		return Report{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return Report{}, err
	}

	return s.load(ctx, id)
}

func (s *Service) List(ctx context.Context, userID, workspaceID string) ([]Report, error) {
	if err := s.requireMember(ctx, userID, workspaceID); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id, workspace_id, job_id, created_by_user_id, title,
		       date_from, date_to, include_photos, include_notes,
		       include_voice, include_files, status,
		       storage_key, size_bytes, page_count, error_msg,
		       created_at, updated_at, deleted_at
		FROM reports
		WHERE workspace_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
	`, workspaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Report
	for rows.Next() {
		r, err := scanReport(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	if out == nil {
		out = []Report{}
	}
	return out, rows.Err()
}

func (s *Service) Get(ctx context.Context, userID, reportID string) (Report, error) {
	r, err := s.load(ctx, reportID)
	if err != nil {
		return Report{}, err
	}
	if err := s.requireMember(ctx, userID, r.WorkspaceID); err != nil {
		return Report{}, err
	}
	return r, nil
}

// LoadForWorker loads a report by ID with no auth checks (internal worker use only).
func (s *Service) LoadForWorker(ctx context.Context, reportID string) (Report, error) {
	return s.load(ctx, reportID)
}

func (s *Service) SetRendering(ctx context.Context, reportID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE reports SET status = 'rendering', updated_at = now() WHERE id = $1
	`, reportID)
	return err
}

func (s *Service) SetReady(ctx context.Context, reportID, storageKey string, sizeBytes int64, pageCount int) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE reports
		SET status = 'ready', storage_key = $2, size_bytes = $3, page_count = $4, updated_at = now()
		WHERE id = $1
	`, reportID, storageKey, sizeBytes, pageCount)
	return err
}

func (s *Service) SetFailed(ctx context.Context, reportID, errMsg string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE reports SET status = 'failed', error_msg = $2, updated_at = now() WHERE id = $1
	`, reportID, errMsg)
	return err
}

func (s *Service) requireMember(ctx context.Context, userID, workspaceID string) error {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, userID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("not a workspace member")
		}
		return err
	}
	return nil
}

func (s *Service) load(ctx context.Context, id string) (Report, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, workspace_id, job_id, created_by_user_id, title,
		       date_from, date_to, include_photos, include_notes,
		       include_voice, include_files, status,
		       storage_key, size_bytes, page_count, error_msg,
		       created_at, updated_at, deleted_at
		FROM reports WHERE id = $1
	`, id)
	return scanReport(row)
}

type scannable interface {
	Scan(dest ...any) error
}

func scanReport(row scannable) (Report, error) {
	var r Report
	err := row.Scan(
		&r.ID, &r.WorkspaceID, &r.JobID, &r.CreatedByUserID, &r.Title,
		&r.DateFrom, &r.DateTo, &r.IncludePhotos, &r.IncludeNotes,
		&r.IncludeVoice, &r.IncludeFiles, &r.Status,
		&r.StorageKey, &r.SizeBytes, &r.PageCount, &r.ErrorMsg,
		&r.CreatedAt, &r.UpdatedAt, &r.DeletedAt,
	)
	return r, err
}
