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

### Phase 2 stack (primary dev path)

The web dashboard + Go API + Postgres + MinIO run via Docker Compose from the repo root:

```bash
cp .env.example .env   # first time only
docker compose up --build
```

- Web: http://localhost:3000
- API health: http://localhost:8080/health
- MinIO: http://localhost:9000 (console: http://localhost:9001)

On Cloud Agent VMs, Docker may need `sudo service docker start` before the first `docker compose` run. If you see permission errors, use `sudo docker compose …` or ensure the `ubuntu` user is in the `docker` group (requires a new shell after `usermod`).

Run long-lived `docker compose up` in a **tmux** session so it survives backgrounding.

### Lint / typecheck / tests

| Surface | Command | Notes |
| --- | --- | --- |
| Web (Next.js) | `cd web && npx tsc --noEmit` | Typecheck without Docker |
| Web lint | `cd web && npm run lint` | **Interactive** on first run (Next.js 15 prompts for ESLint setup); prefer `tsc` in automation |
| API (Go) | Built inside the `api` Docker image | No `*_test.go` files in repo yet |
| Flutter app | `cd app && flutter test` | Flutter SDK is **not** pre-installed on Cloud VMs; install separately for mobile work |

### Hello-world verification

1. `curl http://localhost:8080/health` → `{"status":"ok"}`
2. Sign up via API: `POST /api/v1/auth/signup` with `email`, `password`, optional `name`
3. Open http://localhost:3000/login and sign in → lands on `/jobs` with workspace shell

Magic-link and password-reset emails are logged to the **API container stdout** when `DEV_LOG_EMAIL_LINKS=true` (default in `docker-compose.yml`).

### Not on the default Cloud VM

- **Flutter mobile app** — see [`app/README.md`](app/README.md); needs Flutter 3.41+, Android/iOS toolchain
- **Landing site (PHP)** — `php -S 127.0.0.1:8080 -t landing` conflicts with API port 8080 unless you change one
