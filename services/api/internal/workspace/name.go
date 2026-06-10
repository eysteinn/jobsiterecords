package workspace

import "context"

func (s *Service) Name(ctx context.Context, workspaceID string) (string, error) {
	var name string
	err := s.pool.QueryRow(ctx, `SELECT name FROM workspaces WHERE id = $1`, workspaceID).Scan(&name)
	return name, err
}
