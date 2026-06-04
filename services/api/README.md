# Job Site Records API

Go REST API for auth, workspaces, sync, and billing.

## Run (Docker Compose)

From the repo root:

```bash
docker compose up --build
```

- API: http://localhost:8080/health
- Web: http://localhost:3000
- MinIO: http://localhost:9000 (API console: http://localhost:9001)

For blob upload from a physical phone, set `S3_PUBLIC_ENDPOINT` in the repo root `.env` (see `.env.example`) to your LAN IP on port 9000, then recreate the API container:

```bash
docker compose up -d api
```

Flutter uses the same `.env` via `app/.env` → `../.env`; set `API_BASE_URL` to the same host on port 8080 and fully restart `flutter run`.

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
| POST | `/api/v1/auth/oauth/google` | Sign in with Google ID token (`{"id_token":"…"}`) |
| GET | `/api/v1/workspaces` | List workspaces |
| POST | `/api/v1/workspaces/{id}/leave` | Member leave workspace |

## M2–M3 sync endpoints (auth required)

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/v1/workspaces/{id}/jobs` | List workspace jobs |
| GET | `/api/v1/workspaces/{id}/assignments` | Job IDs assigned to current user (owners: all jobs) |
| GET | `/api/v1/jobs/{id}` | Job bundle (`?since=` for item delta) |
| PUT | `/api/v1/jobs/{id}` | Upsert job (LWW by `updated_at`) |
| PUT | `/api/v1/jobs/{id}/items/{itemId}` | Upsert item (note + media item metadata) |

## M4 media endpoints (auth required)

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/v1/items/{itemId}/media-files` | Mint signed PUT URL; creates `media_files` row (`status=pending`) |
| POST | `/api/v1/media-files/{id}/complete` | Verify S3 object + mark `status=uploaded` |
| GET | `/api/v1/media-files/{id}/download` | Redirect to signed GET URL (`?inline=1` for browser display) |
| GET | `/api/v1/items/{itemId}/thumb?w=512` | Lazy thumbnail (resize + S3 cache) |

Job bundle (`GET /api/v1/jobs/{id}`) includes `media_files` metadata array alongside `items`.

Migrations run automatically on API startup. To apply them without starting the server:

```bash
# From services/api/ (Postgres must be reachable)
./scripts/migrate.sh

# Or directly:
DATABASE_URL=postgres://sitelog:sitelog@localhost:5432/sitelog?sslmode=disable go run ./cmd/migrate
```

Uses the same `schema_migrations` tracking as the API — already-applied files are skipped.

## Google OAuth

Set `GOOGLE_CLIENT_ID` to a comma-separated list of OAuth client IDs allowed in ID token `aud` (typically Web + Android + iOS clients from Google Cloud Console). When unset, `POST /api/v1/auth/oauth/google` returns `503 oauth_not_configured`.

```bash
curl -sS -X POST http://localhost:8080/api/v1/auth/oauth/google \
  -H 'Content-Type: application/json' \
  -d '{"id_token":"YOUR_ID_TOKEN"}'
```

The web dashboard completes the authorization-code flow in Next.js and forwards the `id_token` to this endpoint. Flutter sends the ID token from `google_sign_in` directly.
