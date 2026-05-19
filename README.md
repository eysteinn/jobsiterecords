# Job Site Records (jobsiterecords.com)

> Local-first field notes for contractors. Photos, voice notes, captions, tags. **Free. Local. Private.**

This repository is a **monorepo**. No code lives at the root — only top-level folders, this README, and meta files. See [`docs/high-level-design.md`](docs/high-level-design.md) for the full design.

## Layout

| Folder | What lives here | Status |
| --- | --- | --- |
| [`app/`](app/) | Flutter mobile app (Android + iOS) — the MVP | Active |
| [`landing/`](landing/) | Early-access site for jobsiterecords.com (PHP + SQLite waitlist) | Active |
| [`services/`](services/) | Backend services (API, sync, auth, transcription, PDF) | Placeholder — built when the paid tier is greenlit |
| [`docs/`](docs/) | Design docs, MVP brief, UI mockups | Active |

Future top-level folders (added only when justified by actual work):

| Folder | What it will hold |
| --- | --- |
| `web/` | Web dashboard for the paid tier |
| `shared/` | Cross-language contracts (e.g. JSON Schema for the `job.json` export) |
| `infra/` | Infrastructure-as-code, once there's anything to deploy |
| `tools/` | One-off scripts, codegen, CI helpers |

## Conventions

- **No code in the repo root.** Every code file is under exactly one top-level folder.
- **Each top-level folder owns its own toolchain.** No global build system.
- **Cross-cutting contracts** belong in `shared/` (when it exists) or in `docs/` until then.

## Start here

- New to the project? Read [`docs/mvp.txt`](docs/mvp.txt), then [`docs/high-level-design.md`](docs/high-level-design.md).
- Want to run the app? See [`app/README.md`](app/README.md).
