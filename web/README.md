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

### Google Places (address autocomplete)

Set `NEXT_PUBLIC_GOOGLE_MAPS` in the repo root `.env` (or pass through Docker Compose). Without a key, the site address field is a plain text box.

Use a **browser-restricted** API key (HTTP referrer = your web origin, e.g. `http://localhost:3000/*`). Enable **Places API (New)** on the project. Manual entry still works without picking a suggestion.

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_GOOGLE_MAPS` | Browser Places autocomplete key for job address field |

The mobile app uses the same Google Cloud project key via `GOOGLE_MAPS` with Android/iOS restrictions — see [`app/README.md`](../app/README.md).

## Milestone status

- **M0** — shell, nav, empty states, command palette
- **M1** — real auth (signup, login, magic link, Google OAuth, forgot/reset password, JWT + refresh)
