package jobs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Job struct {
	ID              string     `json:"id"`
	WorkspaceID     string     `json:"workspace_id"`
	Name            string     `json:"name"`
	ClientName      *string    `json:"client_name,omitempty"`
	Address         *string    `json:"address,omitempty"`
	JobNumber       *string    `json:"job_number,omitempty"`
	Status          string     `json:"status"`
	StartDate       *string    `json:"start_date,omitempty"`
	EndDate         *string    `json:"end_date,omitempty"`
	Notes           *string    `json:"notes,omitempty"`
	CoverItemID     *string    `json:"cover_item_id,omitempty"`
	CreatedByUserID string     `json:"created_by_user_id"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	DeletedAt       *time.Time `json:"deleted_at,omitempty"`
}

type Item struct {
	ID              string     `json:"id"`
	WorkspaceID     string     `json:"workspace_id"`
	JobID           string     `json:"job_id"`
	Kind            string     `json:"kind"`
	Caption         *string    `json:"caption,omitempty"`
	Body            *string    `json:"body,omitempty"`
	CapturedAt      time.Time  `json:"captured_at"`
	CreatedByUserID string     `json:"created_by_user_id"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	DeletedAt       *time.Time `json:"deleted_at,omitempty"`
}

type JobBundle struct {
	Job        Job         `json:"job"`
	Items      []Item      `json:"items"`
	MediaFiles []MediaFile `json:"media_files"`
	ReadOnly   bool        `json:"read_only,omitempty"`
}

type Service struct {
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

func (s *Service) ListWorkspaceJobs(ctx context.Context, userID, workspaceID string) ([]Job, error) {
	if err := s.requireMember(ctx, userID, workspaceID); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id, workspace_id, name, client_name, address, job_number, status,
		       start_date::text, end_date::text, notes, cover_item_id::text,
		       created_by_user_id, created_at, updated_at, deleted_at
		FROM jobs
		WHERE workspace_id = $1 AND deleted_at IS NULL
		ORDER BY updated_at DESC
	`, workspaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanJobs(rows)
}

func (s *Service) GetJobBundle(ctx context.Context, userID, jobID string, since *time.Time) (JobBundle, error) {
	job, readOnly, err := s.getJobAccess(ctx, userID, jobID)
	if err != nil {
		return JobBundle{}, err
	}
	items, err := s.listItems(ctx, jobID, since)
	if err != nil {
		return JobBundle{}, err
	}
	media, err := s.listMediaFiles(ctx, jobID, since)
	if err != nil {
		return JobBundle{}, err
	}
	return JobBundle{Job: job, Items: items, MediaFiles: media, ReadOnly: readOnly}, nil
}

func (s *Service) UpsertJob(ctx context.Context, userID string, in Job) (Job, error) {
	if in.WorkspaceID == "" || in.ID == "" || in.Name == "" {
		return Job{}, errors.New("missing required job fields")
	}
	if err := s.requireWrite(ctx, userID, in.WorkspaceID, in.ID); err != nil {
		return Job{}, err
	}

	var existingUpdated time.Time
	err := s.pool.QueryRow(ctx, `SELECT updated_at FROM jobs WHERE id = $1`, in.ID).Scan(&existingUpdated)
	isNew := errors.Is(err, pgx.ErrNoRows)
	if err != nil && !isNew {
		return Job{}, err
	}

	resolved := in.UpdatedAt
	if !isNew {
		if existingUpdated.After(in.UpdatedAt) {
			return s.fetchJob(ctx, in.ID)
		}
	}

	if isNew {
		_, err = s.pool.Exec(ctx, `
			INSERT INTO jobs (
				id, workspace_id, name, client_name, address, job_number, status,
				start_date, end_date, notes, cover_item_id, created_by_user_id,
				created_at, updated_at, deleted_at
			) VALUES (
				$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15
			)
		`, in.ID, in.WorkspaceID, in.Name, in.ClientName, in.Address, in.JobNumber, in.Status,
			in.StartDate, in.EndDate, in.Notes, in.CoverItemID, userID,
			in.CreatedAt, resolved, in.DeletedAt)
		if err != nil {
			return Job{}, err
		}
		role, _ := s.memberRole(ctx, userID, in.WorkspaceID)
		if role == "owner" || role == "member" {
			_, _ = s.pool.Exec(ctx, `
				INSERT INTO job_assignments (job_id, user_id, assigned_by_user_id, assigned_at)
				VALUES ($1, $2, $2, now())
				ON CONFLICT (job_id, user_id) DO NOTHING
			`, in.ID, userID)
		}
	} else {
		_, err = s.pool.Exec(ctx, `
			UPDATE jobs SET
				name = $2, client_name = $3, address = $4, job_number = $5, status = $6,
				start_date = $7, end_date = $8, notes = $9, cover_item_id = $10,
				updated_at = $11, deleted_at = $12
			WHERE id = $1 AND workspace_id = $13
		`, in.ID, in.Name, in.ClientName, in.Address, in.JobNumber, in.Status,
			in.StartDate, in.EndDate, in.Notes, in.CoverItemID, resolved, in.DeletedAt, in.WorkspaceID)
		if err != nil {
			return Job{}, err
		}
	}

	return s.fetchJob(ctx, in.ID)
}

func (s *Service) UpsertItem(ctx context.Context, userID, jobID string, in Item) (Item, error) {
	if in.ID == "" || in.JobID == "" || in.Kind == "" {
		return Item{}, errors.New("missing required item fields")
	}
	if jobID != in.JobID {
		return Item{}, errors.New("job id mismatch")
	}

	job, readOnly, err := s.getJobAccess(ctx, userID, jobID)
	if err != nil {
		return Item{}, err
	}
	if readOnly {
		return Item{}, errors.New("read_only")
	}
	in.WorkspaceID = job.WorkspaceID

	var existingUpdated time.Time
	err = s.pool.QueryRow(ctx, `SELECT updated_at FROM items WHERE id = $1`, in.ID).Scan(&existingUpdated)
	isNew := errors.Is(err, pgx.ErrNoRows)
	if err != nil && !isNew {
		return Item{}, err
	}

	resolved := in.UpdatedAt
	if !isNew {
		if existingUpdated.After(in.UpdatedAt) {
			return s.fetchItem(ctx, in.ID)
		}
	}

	if isNew {
		_, err = s.pool.Exec(ctx, `
			INSERT INTO items (
				id, workspace_id, job_id, kind, caption, body, captured_at,
				created_by_user_id, created_at, updated_at, deleted_at
			) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		`, in.ID, in.WorkspaceID, in.JobID, in.Kind, in.Caption, in.Body, in.CapturedAt,
			userID, in.CreatedAt, resolved, in.DeletedAt)
	} else {
		_, err = s.pool.Exec(ctx, `
			UPDATE items SET
				kind = $2, caption = $3, body = $4, captured_at = $5,
				updated_at = $6, deleted_at = $7
			WHERE id = $1 AND job_id = $8
		`, in.ID, in.Kind, in.Caption, in.Body, in.CapturedAt, resolved, in.DeletedAt, jobID)
	}
	if err != nil {
		return Item{}, err
	}
	return s.fetchItem(ctx, in.ID)
}

func (s *Service) ListAssignedJobIDs(ctx context.Context, userID, workspaceID string) ([]string, error) {
	role, err := s.memberRole(ctx, userID, workspaceID)
	if err != nil {
		return nil, err
	}
	if role == "owner" {
		rows, err := s.pool.Query(ctx, `
			SELECT id FROM jobs WHERE workspace_id = $1 AND deleted_at IS NULL
		`, workspaceID)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		var ids []string
		for rows.Next() {
			var id string
			if err := rows.Scan(&id); err != nil {
				return nil, err
			}
			ids = append(ids, id)
		}
		return ids, rows.Err()
	}
	rows, err := s.pool.Query(ctx, `
		SELECT job_id FROM job_assignments
		WHERE user_id = $1 AND revoked_at IS NULL
		  AND job_id IN (SELECT id FROM jobs WHERE workspace_id = $2 AND deleted_at IS NULL)
	`, userID, workspaceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (s *Service) requireMember(ctx context.Context, userID, workspaceID string) error {
	_, err := s.memberRole(ctx, userID, workspaceID)
	return err
}

func (s *Service) memberRole(ctx context.Context, userID, workspaceID string) (string, error) {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, userID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", errors.New("not a workspace member")
		}
		return "", err
	}
	return role, nil
}

func (s *Service) requireWrite(ctx context.Context, userID, workspaceID, jobID string) error {
	role, err := s.memberRole(ctx, userID, workspaceID)
	if err != nil {
		return err
	}
	if role == "owner" {
		return nil
	}
	var exists bool
	err = s.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM job_assignments
			WHERE job_id = $1 AND user_id = $2 AND revoked_at IS NULL
		)
	`, jobID, userID).Scan(&exists)
	if err != nil {
		return err
	}
	if !exists {
		return errors.New("not assigned to job")
	}
	return nil
}

func (s *Service) getJobAccess(ctx context.Context, userID, jobID string) (Job, bool, error) {
	job, err := s.fetchJob(ctx, jobID)
	if err != nil {
		return Job{}, false, err
	}
	role, err := s.memberRole(ctx, userID, job.WorkspaceID)
	if err != nil {
		return Job{}, false, err
	}
	if role == "owner" {
		return job, false, nil
	}
	var assigned bool
	err = s.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM job_assignments
			WHERE job_id = $1 AND user_id = $2 AND revoked_at IS NULL
		)
	`, jobID, userID).Scan(&assigned)
	if err != nil {
		return Job{}, false, err
	}
	if !assigned {
		return Job{}, false, errors.New("no access")
	}
	return job, false, nil
}

func (s *Service) fetchJob(ctx context.Context, id string) (Job, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, workspace_id, name, client_name, address, job_number, status,
		       start_date::text, end_date::text, notes, cover_item_id::text,
		       created_by_user_id, created_at, updated_at, deleted_at
		FROM jobs WHERE id = $1
	`, id)
	return scanJob(row)
}

func (s *Service) fetchItem(ctx context.Context, id string) (Item, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT id, workspace_id, job_id, kind, caption, body, captured_at,
		       created_by_user_id, created_at, updated_at, deleted_at
		FROM items WHERE id = $1
	`, id)
	return scanItem(row)
}

func (s *Service) listItems(ctx context.Context, jobID string, since *time.Time) ([]Item, error) {
	q := `
		SELECT id, workspace_id, job_id, kind, caption, body, captured_at,
		       created_by_user_id, created_at, updated_at, deleted_at
		FROM items WHERE job_id = $1
	`
	args := []any{jobID}
	if since != nil {
		q += ` AND updated_at > $2`
		args = append(args, *since)
	}
	q += ` ORDER BY captured_at DESC`
	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Item
	for rows.Next() {
		it, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, it)
	}
	if out == nil {
		out = []Item{}
	}
	return out, rows.Err()
}

type scannable interface {
	Scan(dest ...any) error
}

func scanJob(row scannable) (Job, error) {
	var j Job
	var cover *string
	err := row.Scan(
		&j.ID, &j.WorkspaceID, &j.Name, &j.ClientName, &j.Address, &j.JobNumber, &j.Status,
		&j.StartDate, &j.EndDate, &j.Notes, &cover, &j.CreatedByUserID,
		&j.CreatedAt, &j.UpdatedAt, &j.DeletedAt,
	)
	j.CoverItemID = cover
	return j, err
}

func scanItem(row scannable) (Item, error) {
	var it Item
	err := row.Scan(
		&it.ID, &it.WorkspaceID, &it.JobID, &it.Kind, &it.Caption, &it.Body, &it.CapturedAt,
		&it.CreatedByUserID, &it.CreatedAt, &it.UpdatedAt, &it.DeletedAt,
	)
	return it, err
}

func scanJobs(rows pgx.Rows) ([]Job, error) {
	var out []Job
	for rows.Next() {
		j, err := scanJob(rows)
		if err != nil {
			return nil, fmt.Errorf("scan job: %w", err)
		}
		out = append(out, j)
	}
	return out, rows.Err()
}
