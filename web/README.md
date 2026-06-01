# Job Site Records — Web Dashboard

Next.js dashboard for workspace owners and members.

## Run (Docker Compose)

From the repo root:

```bash
docker compose up --build
```

Open http://localhost:3000

Auth flows proxy through `/api/auth/*` so session cookies stay on the web origin.

## Milestone status

- **M0** — shell, nav, empty states, command palette
- **M1** — real auth (signup, login, magic link, forgot/reset password, JWT + refresh)
