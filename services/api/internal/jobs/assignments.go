package jobs

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

type JobAssignment struct {
	JobID  string `json:"job_id"`
	UserID string `json:"user_id"`
}

type AssignmentsResponse struct {
	AssignedJobIDs []string          `json:"assigned_job_ids,omitempty"`
	Assignments    []JobAssignment   `json:"assignments,omitempty"`
}

var (
	ErrNotOwner          = errors.New("owner access required")
	ErrNotActiveMember   = errors.New("user is not an active workspace member")
	ErrAssignmentExists  = errors.New("assignment already exists")
)

func (s *Service) GetAssignments(ctx context.Context, userID, workspaceID string) (AssignmentsResponse, error) {
	role, err := s.memberRole(ctx, userID, workspaceID)
	if err != nil {
		return AssignmentsResponse{}, err
	}
	if role == "owner" {
		rows, err := s.pool.Query(ctx, `
			SELECT ja.job_id, ja.user_id
			FROM job_assignments ja
			JOIN jobs j ON j.id = ja.job_id
			WHERE j.workspace_id = $1 AND j.deleted_at IS NULL AND ja.revoked_at IS NULL
			ORDER BY ja.job_id, ja.user_id
		`, workspaceID)
		if err != nil {
			return AssignmentsResponse{}, err
		}
		defer rows.Close()
		assignments := make([]JobAssignment, 0)
		for rows.Next() {
			var a JobAssignment
			if err := rows.Scan(&a.JobID, &a.UserID); err != nil {
				return AssignmentsResponse{}, err
			}
			assignments = append(assignments, a)
		}
		if err := rows.Err(); err != nil {
			return AssignmentsResponse{}, err
		}
		return AssignmentsResponse{Assignments: assignments}, nil
	}
	ids, err := s.ListAssignedJobIDs(ctx, userID, workspaceID)
	if err != nil {
		return AssignmentsResponse{}, err
	}
	return AssignmentsResponse{AssignedJobIDs: ids}, nil
}

func (s *Service) AssignMember(ctx context.Context, ownerID, workspaceID, jobID, memberUserID string) error {
	if err := s.requireOwner(ctx, ownerID, workspaceID); err != nil {
		return err
	}
	if err := s.requireActiveMember(ctx, workspaceID, memberUserID); err != nil {
		return err
	}
	var jobWorkspace string
	err := s.pool.QueryRow(ctx, `
		SELECT workspace_id FROM jobs WHERE id = $1 AND deleted_at IS NULL
	`, jobID).Scan(&jobWorkspace)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("job not found")
		}
		return err
	}
	if jobWorkspace != workspaceID {
		return errors.New("job not in workspace")
	}
	_, err = s.pool.Exec(ctx, `
		INSERT INTO job_assignments (job_id, user_id, assigned_by_user_id, assigned_at)
		VALUES ($1, $2, $3, now())
		ON CONFLICT (job_id, user_id) DO UPDATE SET
			revoked_at = NULL,
			assigned_by_user_id = EXCLUDED.assigned_by_user_id,
			assigned_at = now()
	`, jobID, memberUserID, ownerID)
	return err
}

func (s *Service) UnassignMember(ctx context.Context, ownerID, workspaceID, jobID, memberUserID string) error {
	if err := s.requireOwner(ctx, ownerID, workspaceID); err != nil {
		return err
	}
	var jobWorkspace string
	err := s.pool.QueryRow(ctx, `
		SELECT workspace_id FROM jobs WHERE id = $1 AND deleted_at IS NULL
	`, jobID).Scan(&jobWorkspace)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("job not found")
		}
		return err
	}
	if jobWorkspace != workspaceID {
		return errors.New("job not in workspace")
	}
	tag, err := s.pool.Exec(ctx, `
		UPDATE job_assignments
		SET revoked_at = now()
		WHERE job_id = $1 AND user_id = $2 AND revoked_at IS NULL
	`, jobID, memberUserID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("assignment not found")
	}
	return nil
}

func (s *Service) requireOwner(ctx context.Context, userID, workspaceID string) error {
	role, err := s.memberRole(ctx, userID, workspaceID)
	if err != nil {
		return err
	}
	if role != "owner" {
		return ErrNotOwner
	}
	return nil
}

func (s *Service) requireActiveMember(ctx context.Context, workspaceID, memberUserID string) error {
	var role string
	err := s.pool.QueryRow(ctx, `
		SELECT role FROM workspace_memberships
		WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'
	`, workspaceID, memberUserID).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotActiveMember
		}
		return err
	}
	if role != "member" {
		return errors.New("can only assign workspace members")
	}
	return nil
}

func (s *Service) assignedJobIDSet(ctx context.Context, userID, workspaceID string) (map[string]bool, error) {
	ids, err := s.ListAssignedJobIDs(ctx, userID, workspaceID)
	if err != nil {
		return nil, err
	}
	set := make(map[string]bool, len(ids))
	for _, id := range ids {
		set[id] = true
	}
	return set, nil
}

func (s *Service) RevokeAllAssignments(ctx context.Context, workspaceID, userID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE job_assignments ja
		SET revoked_at = now()
		FROM jobs j
		WHERE ja.job_id = j.id
		  AND j.workspace_id = $1
		  AND ja.user_id = $2
		  AND ja.revoked_at IS NULL
	`, workspaceID, userID)
	return err
}
