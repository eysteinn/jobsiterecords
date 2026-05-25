# Job Site Records — Backend Services

Phase 2 backend services for the web dashboard, sync, and workers.

## Run locally

From the repo root:

```bash
docker compose up --build
```

| Service | URL | Status |
| --- | --- | --- |
| `api/` | http://localhost:8080 | **M1 implemented** — auth, workspaces, Postgres migrations |
| `pdf/` | — | Not started (M7) |
| `transcribe/` | — | Post-MVP |

See [`api/README.md`](api/README.md) for endpoint list.

## Architecture (MVP target)

```
services/
├── api/          Go — auth, CRUD, sync, signed URLs, Paddle webhooks, email
└── pdf/          Rust — HTML → PDF worker (future)
```

Auth, sync, and webhooks live inside **`api/`** for MVP — no separate `auth/`, `sync/`, or `webhooks/` services until load justifies splitting.

## Rules

- Each service is its own deployable unit with its own README, dependency manifest, and CI lane.
- Cross-language contracts live in `shared/` (OpenAPI) when introduced.
- Local dev uses **Docker Compose** — no host Go/Node toolchain required.
