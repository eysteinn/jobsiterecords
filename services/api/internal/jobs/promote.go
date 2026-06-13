package jobs

import (
	"context"
	"errors"
)

type PromoteLocalJobInput struct {
	Job   Job    `json:"job"`
	Items []Item `json:"items"`
}

// PromoteLocalJob copies a client-local job bundle into a workspace (one-way promotion).
func (s *Service) PromoteLocalJob(ctx context.Context, userID, workspaceID string, in PromoteLocalJobInput) (Job, error) {
	if in.Job.ID == "" || in.Job.Name == "" {
		return Job{}, errors.New("missing required job fields")
	}
	if err := s.requireMember(ctx, userID, workspaceID); err != nil {
		return Job{}, err
	}
	if err := s.requireWorkspaceWritable(ctx, workspaceID); err != nil {
		return Job{}, err
	}
	if err := s.requireWorkspaceSyncPush(ctx, workspaceID); err != nil {
		return Job{}, err
	}

	var exists bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM jobs WHERE id = $1 AND workspace_id = $2 AND deleted_at IS NULL
		)
	`, in.Job.ID, workspaceID).Scan(&exists)
	if err != nil {
		return Job{}, err
	}
	if exists {
		return s.fetchJob(ctx, in.Job.ID)
	}

	in.Job.WorkspaceID = workspaceID
	job, err := s.UpsertJob(ctx, userID, in.Job)
	if err != nil {
		return Job{}, err
	}
	for _, item := range in.Items {
		item.WorkspaceID = workspaceID
		item.JobID = job.ID
		if _, err := s.UpsertItem(ctx, userID, job.ID, item, nil); err != nil {
			return Job{}, err
		}
	}
	return job, nil
}
