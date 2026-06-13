# Agent guide — Job Site Records

Instructions for AI coding agents working in this repository.

## Project overview

**Job Site Records** ([jobsiterecords.com](https://jobsiterecords.com)) is a local-first field record for contractors: photos, voice notes, text notes, files, tags, and export — organized by job. Not a CRM or estimating tool.

This is a **monorepo**. No application code lives at the repo root.

| Folder | Purpose |
| --- | --- |
| [`app/`](app/) | Flutter mobile app (Android + iOS) — Phase 1 |
| [`web/`](web/) | Next.js web dashboard — Phase 2 |
| [`services/`](services/) | Backend (`api/` Go, `pdf/` Rust worker) |
| [`landing/`](landing/) | Marketing site + waitlist (PHP + SQLite) |
| [`docs/`](docs/) | Design docs and plans |
| [`deploy/`](deploy/) | Production deployment notes |

**Start here for context:**

- [`README.md`](README.md) — layout and local dev
- [`docs/high-level-design.md`](docs/high-level-design.md) — **canonical** product, architecture, phasing, and implementation status
- [`docs/web-dashboard-design.md`](docs/web-dashboard-design.md) — web dashboard spec
- [`docs/sync-strategy-plan.md`](docs/sync-strategy-plan.md) — sync design

**Phasing:** Phase 1 = mobile app (local-first, free). Phase 2 = web dashboard + cloud sync + teams (completes the MVP). The app stays free without cloud sync.

## Priority: keep `docs/high-level-design.md` up to date

`docs/high-level-design.md` is the single source of truth for what the system is, what we are building toward, and what is already implemented. **It must always reflect the current repo.**

After any **significant code change**, update `docs/high-level-design.md` in the **same task** as the code. Do not defer doc updates to a follow-up PR or leave the design doc stale.

### What counts as significant

Update the doc when the change affects any of:

- Product scope, phasing, or milestones
- Architecture, data model, storage, sync, or export behavior
- New or removed features, screens, flows, or APIs
- Landing site structure, SEO pages, or waitlist/backend behavior
- Platform, dependencies, or deployment topology
- Security, privacy, or offline/online behavior
- Implementation status vs the documented target (gaps closed or new gaps)

Skip doc updates only for trivial edits (typos, formatting, renames with no behavior change, comment-only changes).

### What to update in the design doc

1. **Implementation status** — Refresh the table under “Implementation status” and milestone notes so status labels (`implemented`, `partial`, `not started`) match the repo.
2. **Relevant sections** — Edit the sections that describe what changed (architecture, features, phasing, landing, etc.). Remove or correct statements that are no longer true.
3. **Cross-references** — If section numbers or anchors shift, fix internal links.

Keep edits **minimal and accurate**: change only what the code change invalidated; do not rewrite unrelated chapters.

### Workflow

When finishing a significant change:

1. Re-read the affected parts of `docs/high-level-design.md`.
2. Compare doc claims to the code you changed.
3. Patch the doc in the same PR/commit series as the code (unless the user explicitly asked for code only — then call out the required doc updates).
4. In your summary, briefly note what you updated in the design doc (or state that no doc change was needed and why).

If unsure whether a change is significant, **update the doc** — stale design docs are worse than a small extra edit.

This rule is also enforced via [`.cursor/rules/sync-high-level-design.mdc`](.cursor/rules/sync-high-level-design.mdc).

## Repo conventions

- **No code in the repo root.** Every code file belongs under exactly one top-level folder.
- **Each top-level folder owns its toolchain.** No global build system.
- **Minimize scope.** Use the simplest correct diff; do not change unrelated code.
- **Match existing conventions** in naming, types, imports, and patterns before adding new abstractions.
- **Cross-cutting contracts** belong in `shared/` (when it exists) or in `docs/` until then.

## Local development

**Phase 2 stack (web + API):**

```bash
docker compose up --build
```

- Web dashboard: http://localhost:3000
- API health: http://localhost:8080/health

See [`web/README.md`](web/README.md), [`services/api/README.md`](services/api/README.md), and [`app/README.md`](app/README.md) for surface-specific setup.

## Product principles (when making decisions)

- **Narrow scope** — job-centered record and handoff, not a construction PM suite.
- **Simple path** — few steps, plain labels, one obvious primary action; capture must feel as fast as camera roll.
- **Surface parity** — desktop web, mobile web, and the native app are equally viable once the MVP is complete; layout adapts, semantics stay aligned.

When adding features or changing behavior, check whether the design doc’s phasing and non-goals still apply before expanding scope.

## Related design docs

Use these for detail; keep `docs/high-level-design.md` as the overview that ties them together:

| Doc | Use for |
| --- | --- |
| [`docs/high-level-design.md`](docs/high-level-design.md) | Product, architecture, phasing, implementation status |
| [`docs/web-dashboard-design.md`](docs/web-dashboard-design.md) | Web UI, milestones M0–M5+ |
| [`docs/sync-strategy-plan.md`](docs/sync-strategy-plan.md) | Sync protocol and client behavior |
| [`docs/web-photo-annotation-plan.md`](docs/web-photo-annotation-plan.md) | Photo annotation on web |
| [`docs/job-timeline-photo-grid-plan.md`](docs/job-timeline-photo-grid-plan.md) | Timeline photo grid layout |

When a specialized plan doc and `high-level-design.md` disagree after your change, update both so they stay consistent, with the high-level doc reflecting the current truth at a glance.

## Cursor Cloud specific instructions

These are durable, non-obvious notes for running the Phase 2 stack (web + API) in the Cursor Cloud VM. Standard commands live in the per-surface READMEs and `docker-compose.yml`; this section only captures gotchas.

- **Start the Docker daemon first.** The VM has no init system, so `dockerd` does not auto-start. Before `docker compose up`, launch it (e.g. `sudo dockerd > /tmp/dockerd.log 2>&1 &`) and wait until `sudo docker info` succeeds. Docker is configured with the `fuse-overlayfs` storage driver and `containerd-snapshotter` disabled (required for this kernel) — leave `/etc/docker/daemon.json` as-is.
- **First-boot migration race.** Both `api` and `worker` run DB migrations on startup. On a fresh Postgres volume the `worker` can crash with `migration 001_m1_auth.sql: ... duplicate key value violates unique constraint "pg_extension_name_index"` because it races the `api` on `CREATE EXTENSION`. It is harmless: re-run `docker compose up -d worker` once and it skips already-applied migrations.
- **Don't build `web/` on the host while the compose `web` container runs.** That service bind-mounts `./web` and runs `npm run dev` as root, writing `.next` (root-owned). A concurrent host `npm run build`/`npm run dev` collides on `.next` (e.g. `ENOENT ... _ssgManifest.js`) and leaves root-owned files. For a clean host build: `docker compose stop web`, `sudo rm -rf web/.next`, then `npm run build`, then `docker compose up -d web`.
- **Native Go tooling needs 1.25.** System `go` is 1.22 but the module requires 1.25. Go 1.25 is installed at `/usr/local/go-1.25/bin` and prepended to `PATH` via `~/.bashrc`, so `go test ./...` / `go vet ./...` work from `services/api/`. (The Docker build uses `golang:1.25-alpine`, so the stack itself doesn't need host Go.)
- **`web` lint is not wired up.** `npm run lint` (web) launches an interactive `next lint` ESLint-setup prompt because no ESLint config is committed; it can't run non-interactively. Use `npm run build` (type-checks) for verification instead.
- **External integrations are optional.** Google OAuth/Places, Paddle billing, and SMTP read keys from a repo-root `.env`; without them compose uses defaults and only those specific sub-flows are disabled. Email magic-links/reset links are logged by the API when `DEV_LOG_EMAIL_LINKS=true` (the compose default).
- **Flutter app / landing site are not set up here.** Flutter (`app/`) needs an Android emulator/device and the PHP `landing/` site needs a PHP runtime — neither is installed in this VM. Set them up on demand if a task targets those surfaces.
