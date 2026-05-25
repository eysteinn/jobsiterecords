# Job Site Records API

Go REST API for auth, workspaces, sync, and billing.

## Run (Docker Compose)

From the repo root:

```bash
docker compose up --build
```

- API: http://localhost:8080/health
- Web: http://localhost:3000

## M1 endpoints

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/v1/auth/signup` | Email + password sign-up (creates user + workspace) |
| POST | `/api/v1/auth/login` | Sign in |
| POST | `/api/v1/auth/refresh` | Rotate refresh token |
| POST | `/api/v1/auth/logout` | Revoke session (auth required) |
| GET | `/api/v1/auth/me` | Current user + workspaces |
| POST | `/api/v1/auth/magic-link` | Send magic link |
| GET/POST | `/api/v1/auth/magic-link/verify` | Verify magic link |
| POST | `/api/v1/auth/forgot-password` | Send reset email |
| POST | `/api/v1/auth/reset-password` | Set new password |
| GET | `/api/v1/workspaces` | List workspaces |
| POST | `/api/v1/workspaces/{id}/leave` | Member leave workspace |

## M2–M3 sync endpoints (auth required)

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/v1/workspaces/{id}/jobs` | List workspace jobs |
| GET | `/api/v1/workspaces/{id}/assignments` | Job IDs assigned to current user (owners: all jobs) |
| GET | `/api/v1/jobs/{id}` | Job bundle (`?since=` for item delta) |
| PUT | `/api/v1/jobs/{id}` | Upsert job (LWW by `updated_at`) |
| PUT | `/api/v1/jobs/{id}/items/{itemId}` | Upsert item (note metadata in M3) |

Migrations run automatically on API startup. To apply them without starting the server:

```bash
# From services/api/ (Postgres must be reachable)
./scripts/migrate.sh

# Or directly:
DATABASE_URL=postgres://sitelog:sitelog@localhost:5432/sitelog?sslmode=disable go run ./cmd/migrate
```

Uses the same `schema_migrations` tracking as the API — already-applied files are skipped.
