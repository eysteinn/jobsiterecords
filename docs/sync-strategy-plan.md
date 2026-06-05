# Sync strategy — when and how to sync

**Status:** S1–S4 implemented (mobile auto-sync; API cursors; web auto-refresh + dashboard settings)
**Created:** 2026-06-05
**Scope:** Mobile app (`app/`) sync triggers + Web dashboard (`web/`) freshness + Go API (`services/api/`) support
**Related docs:** [`high-level-design.md`](high-level-design.md) §17.4, [`web-dashboard-design.md`](web-dashboard-design.md) §15 (sync API / protocol)

**North star:** Users should **never have to think about sync**. It happens automatically, quietly, and quickly. Manual sync stays available for the people who want a button — but it is a reassurance, not a requirement. At the same time we **spare the server**: coalesce bursts, poll cheaply, and never sync when there is nothing to do.

---

## 0. Today (baseline)

| Side | Current behavior | Gap |
| --- | --- | --- |
| **Mobile** | **S1 implemented:** `SyncScheduler` auto-syncs in workspace mode (debounced on Save, launch, foreground, connectivity, 15 min periodic); manual pull-to-refresh + Settings kept. Per-row `sync_attempts` + quarantine after 5 permanent failures. See `app/lib/sync/sync_scheduler.dart`. | Web still fetch-on-navigation only (S3). API change cursor (S2) not started. |
| **Web** | **S3 implemented:** visibility-gated cursor polling (20 s job detail / 60 s list) via BFF; delta-merge on job detail; manual Refresh on list + detail. Settings → Live updates (S4). | Job-level sync dots deferred (per-job status indicator planned later). |
| **API** | Has the right primitives already: `GET /jobs/{id}?since=<RFC3339Nano>` returns item/media deltas; `updated_at` last-writer-wins on upserts; media-complete bumps the parent item's `updated_at`. | `jobs.updated_at` is **not** bumped when an item/media changes, so there is no cheap "did this job change?" signal for the jobs list or a poll. |

So the engine and protocol are solid; what's missing is **automatic triggering** (mobile) and **automatic freshness** (web), plus one cheap server-side change signal.

---

## 1. Principles

1. **Automatic by default, manual as an option.** Both surfaces sync without user action; both keep an explicit control.
2. **Eventual consistency is non-negotiable.** Capture is local-first and always works offline; **everything queued syncs eventually** — across app restarts, crashes, and long offline stretches. Failures retry until they succeed (or are provably unrecoverable). Nothing is silently dropped.
3. **Coalesce, don't spam.** A batch of 20 photos must produce **one** sync, not twenty. Debounce writes; rate-limit triggers; back off on failure.
4. **Push is event-driven, pull is interval-driven.** We know exactly when *we* change something (push immediately-ish). We don't know when the *other side* changes, so we pull on a gentle cadence + on natural attention moments (foreground, focus, navigation).
5. **Sync ASAP when it becomes possible.** The moment connectivity returns (or the app reopens) with work queued, flush immediately — backoff is for spam control, not for punishing a user who was in a dead zone.
6. **Only sync when it's worth it.** Skip when local-only, signed out, offline, nothing pending and pulled recently, or already syncing.
7. **Cheap-detect before expensive-fetch.** Poll a tiny "has anything changed?" cursor; only download a full/delta bundle when it actually moved.
8. **Quiet UI.** Background sync is silent (footer state only). Only **manual** sync shows a snackbar. Failures self-heal silently; only the unrecoverable ones are surfaced (never a modal).
9. **Respect the network gate.** Wi-Fi-only stays a blob-upload gate (metadata still flows on cellular). Auto-sync honors it.

---

## 2. Mobile app — when to sync

A small **`SyncScheduler`** (new) owns all automatic triggering and funnels everything through the existing `runForegroundSync` path (renamed conceptually to "run sync"; keep manual snackbars for manual calls only). It enforces coalescing and rate limits so the rest of the app can fire "something changed" / "we're back" signals freely.

### 2.1 Triggers

| # | Trigger | Type | Behavior |
| --- | --- | --- | --- |
| 1 | **Local write** (item/job/media created or edited in a workspace job) | push | **Debounced**: schedule a sync ~**8 s** after the *last* write. A burst of captures keeps resetting the timer → one sync when the user stops. Hard cap: force a sync if writes have been pending > **60 s** even while still capturing. |
| 2 | **App launch / cold start** | push (then pull) | On startup, if anything is `pending`/`failed` in a workspace, flush it ASAP. Guarantees a crash, force-quit, or "captured-then-closed-the-app" never leaves data stuck. |
| 3 | **App foreground / resume** | pull+push | On `AppLifecycleState.resumed`, if last successful sync was > **2 min** ago **or** anything is pending, sync. Catches web edits made while backgrounded. |
| 4 | **Sign-in / workspace switch** | pull+push | Sync once immediately (with a visible indicator) so the user lands on fresh data. |
| 5 | **Connectivity regained** | push | On `connectivity_plus` onConnectivityChanged → online, **reset backoff** and flush any `pending`/`failed` immediately. This is the "offline all day, then sync the moment signal returns" path. |
| 6 | **Periodic safety net** | pull+push | While app is **foregrounded** and in a workspace, a low-frequency timer (every **~15 min**) pulls remote changes and re-attempts anything still `pending`/`failed`. Cancelled when backgrounded. |
| 6b | **Job detail open** | pull+push | While **job detail** is visible in a workspace, poll every **~30 s** so web/supervisor edits appear without pull-to-refresh. Immediate check on open. |
| 7 | **Manual — pull-to-refresh** | pull+push | Keep as-is. Always runs (bypasses rate limit + backoff), shows snackbar. |
| 8 | **Manual — Settings "Sync now"** | pull+push | Keep as-is. Always runs, shows snackbar. |

> No OS background sync (WorkManager / BGTaskScheduler) in v1 — it adds platform complexity, battery/permission surface, and store-review questions for marginal benefit. The foreground + resume + connectivity triggers cover "I opened the app, it's current" and "I captured, it's backed up shortly after". Revisit background sync only if users report stale team data without opening the app.

### 2.2 Coalescing & rate limiting (sparing the server)

The scheduler guarantees:

- **Debounce window** (default 8 s) on write-triggered syncs — batch capture → one sync.
- **Minimum interval** between *automatic* syncs (default **30 s**). Triggers inside the window are dropped or, if there are pending changes, collapsed into one trailing sync when the window opens.
- **Single-flight**: never start a sync while one is running; set a "re-run when done" flag instead.
- **Skip when pointless**: don't even attempt when offline (let trigger #5 wake us), signed out, local-only, or nothing pending and pulled recently. Cheap no-ops while offline; real work only when it can succeed.
- **Exponential backoff on failure**: 30 s → 1 m → 2 m → 5 m → 15 m (cap), reset on success. Avoids hammering a down server. Manual sync and connectivity-regained ignore/reset backoff (see §2.3).
- **Manual always wins**: pull-to-refresh / "Sync now" bypass the min-interval and backoff.

### 2.3 Failure handling, retries & eventual consistency

**Guarantee: nothing is ever lost, and everything syncs eventually.** Capture is local-first — every photo/note/voice/file is written to SQLite + disk immediately, independent of network. Sync is a separate, idempotent step that drains the durable queue.

#### 2.3.1 The durable queue (already in the schema)

Pending work isn't held in memory — it lives in the DB as `sync_state IN ('pending','failed')` on `jobs`, `items`, and `media_files`. This is what makes eventual consistency cheap:

- **Survives everything** — app kill, crash, reboot, OS eviction. On next launch (trigger #2) the queue is still there and gets flushed.
- **Per-row, not per-batch** — `_pushPending` already loops per row and isolates failures: one bad item flips only that row to `failed` and does **not** block the rest. Healthy rows still go up.
- **Idempotent push** — pushes are `PUT` with client-generated UUIDs + `updated_at` LWW, and blob upload is mint → upload → complete keyed by media id. Re-sending a row that actually succeeded is safe (no duplicates), so retrying after an ambiguous failure (e.g. timeout after the server committed) can't corrupt data.

So "retry" is mostly automatic: any trigger re-runs `_pushPending`, which re-selects `pending`/`failed` rows. We just need the *cadence* to be eventual-but-not-spammy, and to keep retrying until success.

#### 2.3.2 Classify errors — retry transient, quarantine permanent

Not all failures should retry forever. `sync_errors.dart` already distinguishes the categories; the scheduler should act on them:

| Class | Examples | Action |
| --- | --- | --- |
| **Transient** | offline, timeout, DNS, connection reset, **5xx**, 429 | Keep retrying with backoff. These *will* eventually succeed. Honor `Retry-After` on 429. |
| **Auth** | 401 | Refresh token once (engine already does this); if refresh fails → surface "Sign in to sync", stop auto-retry until re-auth. |
| **Permanent** | 4xx validation (400/409/413/422), e.g. a file over the size cap or a malformed payload | Retrying won't help. Mark the row `failed`, **track an attempt count**, and after a few tries stop auto-retrying *that row* and surface it (see §2.3.4). Do **not** let one poison row burn battery/server forever. |

> Implementation note: this needs a small schema add — a `sync_attempts` (int) and optional `last_sync_error` (text) column per syncable table, or a sidecar `sync_failures` table. Increment on failure, clear on success. Lets us back off per-row and detect a poison item. (Mentioned in §12-style future-proofing of the design doc: extra local sync columns are expected.)

#### 2.3.3 Backoff that doesn't fight "sync ASAP after offline"

The tension: backoff spares the server, but a user who was offline all day must sync **immediately** when signal returns — not wait out a 15-minute backoff timer. Resolution:

- Backoff governs **automatic, timer-driven** retries only.
- **Connectivity-regained (trigger #5) resets backoff to zero and fires now.** Going offline→online is treated as new information ("the thing that was failing — no network — just changed"), so we don't punish the user for the dead-zone.
- App launch / foreground / sign-in / manual likewise bypass or reset backoff.
- Net effect: while genuinely offline, automatic retries are cheap and slow (and mostly skipped — see "skip when offline" in §2.2); the instant the network is back, we flush hard, once.

#### 2.3.4 Poison items (don't block the queue, don't hide data loss)

If a specific row keeps failing with a *permanent* error after **5** attempts (decision Q6 — permanent = `400/409/413/422`):

- Stop auto-retrying that row so it can't wedge the queue or spam the server, but **keep it on device** (never dropped).
- Surface it honestly: footer/Settings shows e.g. `1 item couldn't sync` with a tap-through to a small list and a **Retry** action. This is the only failure we make the user aware of, because it's the only one that won't self-heal.
- Everything else continues to sync normally around it.

#### 2.3.5 Eventual-consistency checklist

- [x] Pending work is durable in SQLite (✓ today) and re-attempted on launch, foreground, connectivity, periodic, and manual.
- [x] Per-row failure isolation (✓ today) + per-row attempt count (`sync_attempts` schema v5).
- [x] Transient vs permanent classification drives retry vs quarantine (`classifySyncError`).
- [x] Backoff for spam control, but reset on connectivity-regained so offline→online flushes immediately.
- [x] Only unrecoverable failures are surfaced to the user; the rest heal silently.

### 2.4 What changes in code (mobile)

- **New** `app/lib/sync/sync_scheduler.dart`: debounce timer, min-interval clock, backoff (with reset), single-flight; exposes `nudge(reason)` (write/launch/foreground/connectivity/periodic/manual) and delegates to the runner.
- **`bumpDataRevision`** (or the repositories) also calls `scheduler.nudge(write)` when the active context is a workspace. This is the one-line hook that makes capture auto-sync.
- **App launch**: on startup, if `countPending() > 0`, `nudge(launch)` so a previous offline/crashed session drains.
- **App lifecycle**: extend the existing `WidgetsBindingObserver` (or add one) to `nudge(foreground)` on resume and start/stop the periodic timer.
- **Connectivity**: subscribe to `Connectivity().onConnectivityChanged` once (app scope) → on transition to online, **reset backoff** and `nudge(connectivity)`.
- **Per-row retry state**: add `sync_attempts` (+ optional `last_sync_error`) columns (schema migration); `_pushPending` increments on failure, clears on success; classify via `sync_errors.dart` to decide retry vs quarantine.
- **Pending count freshness**: call `refreshPendingCount` on write so the footer ("N pending") is accurate immediately, not only after a sync (current gap).
- **Footer copy**: reflect auto state — e.g. `Synced 2m ago`, `Saving… (3 pending)`, `Offline · will sync when online`, `Sync failed · retrying`, `1 item couldn't sync · tap to retry`. Keep it subtle.

### 2.5 Mobile UX summary

- Capture photos → footer briefly shows pending → within ~8 s it's `Synced just now`. User did nothing.
- **Offline all day on a site** → keep capturing freely (all local) → footer `Offline · will sync when online` → signal returns → everything flushes within seconds (backoff reset). User did nothing.
- Force-quit the app mid-backlog → reopen later → it drains on launch. Nothing lost.
- A single bad item (e.g. oversized file) → everything else syncs; that one shows `couldn't sync · tap to retry`. Honest, isolated, recoverable.
- Wants control → pull-to-refresh or Settings "Sync now" → snackbar confirms. For the button-pressers.

---

## 3. Web dashboard — detecting mobile-added items

The web can't be event-driven without websockets/SSE (out of scope for v1 — extra infra on the Go API). Instead: **visibility-gated polling of a cheap change cursor**, plus the existing manual Refresh. This keeps a manager's open job-detail page fresh without a heavy re-fetch loop.

### 3.1 Strategy

1. **Cheap change-detection first.** Poll a tiny endpoint that returns a per-job (and per-workspace) **change cursor** — the max `updated_at` across the job + its items + media. No bodies, just a timestamp/version.
2. **Delta-fetch only on change.** When the cursor advances, fetch `GET /jobs/{id}?since=<lastCursor>` (already supported) to pull just the new/changed items + media, and merge into client state. Falls back to a full `getJob` if `since` is missing/first load.
3. **Visibility & focus gated.** Poll only while the tab is **visible** (Page Visibility API). Pause when hidden; **immediately** check on `focus`/`visibilitychange → visible`. This is the biggest server saver — background tabs cost nothing.
4. **Gentle cadence with backoff.** Job detail (active attention): poll every **~20 s**. Jobs list: every **~60 s** (or only refresh on focus). When nothing has changed for a while, back off (20 s → 40 s → 60 s cap); reset to fast on any change or user interaction.

### 3.2 Where polling lives

| Screen | Poll target | On change |
| --- | --- | --- |
| **Job detail** (`JobDetailClient`) | Per-job cursor | Delta-fetch `?since=` → merge items/media into React state (no full reload, no scroll jump). Show a subtle "New items added — updated" toast/inline marker. |
| **Jobs list** (`JobsClient`) | Per-workspace cursor (or list `updated_at` once it reflects item activity, see §4) | `router.refresh()` or re-fetch list so "Updated X ago" and counts move. |

A small client hook (`useJobPoll`) handles interval, visibility, focus, backoff, and abort-on-unmount. Polling goes through a new Next.js BFF proxy route (cookie → Bearer), since these are currently server-only fetches.

### 3.3 Manual refresh (web)

- Keep the jobs-list **Refresh** button.
- Add an explicit **Refresh** affordance on job detail too (and make "new items available" tappable to refresh instantly). For the button-pressers, parity with mobile.

### 3.4 Web UX summary

- Manager watching today's job → crew uploads a photo → within ~20 s a subtle "Updated" marker + the new thumb appears. No manual action.
- Switches to another app and back → instant freshness check on focus.
- Wants control → Refresh button anytime.

---

## 4. API support needed (small)

The protocol mostly exists. Two cheap additions spare the server and make polling viable:

1. **Add a `last_activity_at` column on `jobs`, bumped on item/media change** (decision Q4). Today `UpsertItem` touches only the `items` table, so the jobs list and any job-level cursor miss new captures. Within the same transaction as item upsert / media complete, set `jobs.last_activity_at = now`. We deliberately **do not** overload `jobs.updated_at` — that stays the job-content edit timestamp for LWW, so a crew photo doesn't masquerade as a job edit. The jobs list "Updated X ago" and the change cursor read `last_activity_at` (= `MAX(updated_at, last_activity_at)` in effect).

2. **Cheap change-cursor endpoint(s)** for polling — return cursors without bodies:
   - `GET /api/v1/jobs/{id}/cursor` → `{ "cursor": "<RFC3339Nano job.last_activity_at>" }`
   - `GET /api/v1/workspaces/{id}/cursor` → `{ "cursor": "<MAX(last_activity_at) across workspace jobs>" }`
   Add HTTP **ETag / `If-None-Match`** so unchanged polls return **`304 Not Modified`** (tiny response). This is what makes 20 s polling cheap at scale.

> Websockets/SSE/push are deliberately **not** in this plan. Polling a 304-able cursor, visibility-gated, is far simpler operationally and good enough for "team sees field captures within ~20 s". Upgrade later only if real-time collaboration becomes a requirement.

---

## 5. "Sparing the server" — combined budget

| Lever | Mobile | Web |
| --- | --- | --- |
| Debounce bursts | 8 s write debounce → batch = 1 sync | n/a (web rarely bulk-writes) |
| Min interval / cadence | 30 s min between auto syncs | 20 s detail / 60 s list poll |
| Don't poll when away | Periodic only while foregrounded; cancelled on background | Poll only while tab visible; pause when hidden |
| Skip no-op work | Skip if local-only / signed out / offline / nothing pending & pulled recently | `304 Not Modified` on unchanged cursor; delta-fetch only on change |
| Backoff on idle/failure | Exp. backoff on failure (30 s → 15 m cap), **reset on connectivity-regained** | Exp. backoff when no changes |
| Don't retry the unwinnable | Quarantine poison rows after N permanent failures (kept on device, surfaced for manual retry) | n/a |
| Single-flight | Yes | Yes (abort in-flight on new poll) |

Rough worst case for one idle foregrounded user: mobile ~4 pulls/hour (periodic) + web ~180 cursor polls/hour but almost all `304`. Active capture: a handful of real syncs coalesced from many writes. A device offline for hours costs the server **nothing** (attempts are skipped), then one burst flush on reconnect.

---

## 6. Phasing

| Phase | Deliverable | Why first |
| --- | --- | --- |
| **S1 — Mobile auto-push + durable retry** | **Done** — `SyncScheduler` + write-debounce + launch/foreground/connectivity/periodic triggers; backoff with connectivity-reset; schema v5 `sync_attempts` + quarantine; footer + Settings surface; pending-count-on-write | Highest user value: captures back up automatically **and** survive offline/crash. Pure client change, no API work (apart from a local schema migration). |
| **S2 — API change signal** | **Done** — `jobs.last_activity_at` (migration 007); bumped on item/media change; `GET …/cursor` with ETag/304 | Unblocks cheap web polling and keeps jobs list "Updated" accurate. |
| **S3 — Web auto-refresh** | **Done** — `useSyncPoll` + BFF cursor routes; delta-merge on job detail; list `router.refresh()` on change; Refresh on detail | Managers see field activity live. |
| **S4 — Polish** | **Done** — "Updated" banner on job detail; Settings → Live updates (auto-refresh toggle + normal/slower cadence) | Job-level status dots deferred to a later pass. |

---

## 7. Decisions

These resolve the design choices for v1. All defaults are **constants in one place** (a `SyncConfig`) so tuning later is a one-line change, not a refactor.

| # | Question | **Decision** | Rationale |
| --- | --- | --- | --- |
| 1 | **Debounce window** | **8 s**, anchored to the **DB write (Save)** — not shutter taps. Hard cap forces a sync after 60 s of continuous pending. | Batch-first capture writes rows on **Save**, so the timer starts then; sitting on the review screen costs nothing. 8 s coalesces a save-then-edit-caption flurry into one sync. |
| 2 | **Periodic pull cadence** | **15 min** while foregrounded. **No Settings toggle in v1.** | Resume + connectivity triggers already cover the common cases; periodic is just a safety net. Zero-config keeps the "never think about sync" promise. A frequency toggle is S4 polish only if asked for. |
| 3 | **Web poll interval** | **20 s** job detail, **60 s** jobs list, both visibility-gated with backoff to a 60 s cap. | Fast enough that a manager sees field captures within ~20 s; ETag/`304` keeps it cheap. Revisit only if API load data says otherwise. |
| 4 | **Job activity timestamp** | Add a **separate `last_activity_at`** column on `jobs`; bump it on item/media change. Do **not** overload `jobs.updated_at`. | Keeps job-content LWW clean (a new photo isn't a job edit) while giving the list "Updated X ago" and the change cursor a correct signal. See §4.1. |
| 5 | **Background (OS-level) sync** | **Not in v1.** Foreground/launch/connectivity triggers only. | Avoids battery/permission/store-review cost for marginal gain. Eventual consistency still holds, bounded by "next app open" — fine for field→truck→office patterns. Revisit on real complaints. |
| 6 | **Poison-item quarantine** | After **5** failed attempts on a **permanent** error. **Permanent** = `400, 409, 413, 422`. **Transient (retry forever)** = network/offline/timeout, `408, 425, 429, 5xx`. `401` → token refresh path, not a strike. | 5 covers transient blips misclassified as permanent without burning battery/server on a truly bad row. The 4xx split maps cleanly to "client must change the payload" vs "try again later" (`429` honors `Retry-After`). |
| 7 | **Backoff granularity** | **Whole-queue** backoff. Quarantined rows (Q6) are **excluded** from the push set, so a poison row can't trigger or extend backoff for healthy rows. | Simplest correct option: no per-row timers, yet a poison item can't stall the queue because it's no longer in it. Revisit per-row only if a slow (non-poison) row proves to delay others. |
| 8 | **Conflict surfacing** | **Keep silent LWW** in v1 (no conflict UI). | Matches the documented sync protocol; concurrent web+mobile edits to the *same field* are rare today. Add surfacing only when teams hit it in practice. |

### 7.1 Default constants (v1)

| Constant | Value |
| --- | --- |
| Write debounce | 8 s |
| Pending hard-cap (force sync) | 60 s |
| Min interval between auto syncs | 30 s |
| Failure backoff | 30 s → 1 m → 2 m → 5 m → 15 m (cap) |
| Periodic pull (foreground) | 15 min |
| Job detail watch poll | 30 s |
| Resume re-sync threshold | 2 min since last success |
| Web poll — job detail | 20 s (backoff → 60 s cap) |
| Web poll — jobs list | 60 s |
| Poison quarantine threshold | 5 attempts (permanent errors only) |

### 7.2 Still genuinely open (defer, not blocking)

- **Exposing a sync-frequency / auto-sync toggle** for power users — only if requested (S4).
- **Conflict surfacing UX** — when concurrent same-field edits become real.
- **Per-row backoff** — only if a non-poison slow row measurably delays the queue.
