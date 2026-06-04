# Job Site Records — Web Dashboard

Next.js dashboard for workspace owners and members.

## Run (Docker Compose)

From the repo root:

```bash
docker compose up --build
```

Open http://localhost:3000

Auth flows proxy through `/api/auth/*` so session cookies stay on the web origin.

### Google sign-in

Server-side OAuth redirect at `/api/auth/google` (callback sets cookies on the **web** host only — not the API host in production).

Environment variables (see repo root `.env.example`):

| Variable | Purpose |
| --- | --- |
| `GOOGLE_CLIENT_ID` | Web OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Code exchange (BFF only) |
| `APP_URL` | Redirect base, e.g. `http://localhost:3000` |
| `API_INTERNAL_URL` | Server-side API base (Docker: `http://api:8080`) |

Register redirect URI: `{APP_URL}/api/auth/google/callback` in Google Cloud Console.

## Milestone status

- **M0** — shell, nav, empty states, command palette
- **M1** — real auth (signup, login, magic link, Google OAuth, forgot/reset password, JWT + refresh)
