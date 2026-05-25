# Job Site Records (jobsiterecords.com)

> Local-first field notes for contractors. Photos, voice notes, captions, tags. **Free. Local. Private.**

This repository is a **monorepo**. No code lives at the root — only top-level folders, this README, and meta files. See [`docs/high-level-design.md`](docs/high-level-design.md) for the full design.

## Layout

| Folder | What lives here | Status |
| --- | --- | --- |
| [`app/`](app/) | Flutter mobile app (Android + iOS) — Phase 1 | Active |
| [`landing/`](landing/) | Early-access site for jobsiterecords.com (PHP + SQLite waitlist) | Active |
| [`web/`](web/) | Next.js web dashboard (Phase 2) | **M0–M1** — shell + auth |
| [`services/`](services/) | Backend (`api/` Go, `pdf/` Rust worker) | **M1** — auth API in Docker |
| [`docs/`](docs/) | Design docs, MVP brief, UI mockups | Active |

## Phase 2 dashboard (local dev)

```bash
docker compose up --build
```

- Web dashboard: http://localhost:3000
- API health: http://localhost:8080/health

See [`web/README.md`](web/README.md) and [`services/api/README.md`](services/api/README.md).

Future top-level folders (added only when justified by actual work):

| Folder | What it will hold |
| --- | --- |
| `shared/` | Cross-language contracts (OpenAPI) |
| `infra/` | Infrastructure-as-code, once there's anything to deploy |
| `tools/` | One-off scripts, codegen, CI helpers |

## Conventions

- **No code in the repo root.** Every code file is under exactly one top-level folder.
- **Each top-level folder owns its own toolchain.** No global build system.
- **Cross-cutting contracts** belong in `shared/` (when it exists) or in `docs/` until then.

## Start here

- New to the project? Read [`docs/mvp.txt`](docs/mvp.txt), then [`docs/high-level-design.md`](docs/high-level-design.md).
- Want to run the app? See [`app/README.md`](app/README.md).
