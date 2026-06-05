# Job Site Records — High-Level Design

> **Job notes, photos, and files — organized by project.** A free offline field record for contractors. Capture photos, voice notes, text notes, tags, and attachments on the job, then export a clean record when you need it. **Not a CRM. Not estimating software. Just the job record.**

**Principles:** **Narrow scope** — a simple **job-centered record** (photos, voice, text notes, files, tags, timeline, export) and **handoff** (zip; Phase 2 PDF/dashboard/sync). Not a construction PM suite, accounting stack, or “everything app.” **Simple path** — few steps, plain labels, one obvious primary action; the capture loop must feel **as fast as camera roll or texting yourself** or users will abandon it. Defer depth to Settings or Phase 2.

Product and marketing domain: **jobsiterecords.com**.

**Phasing (read this first)**  
- **MVP (product scope):** the minimum viable product is **both** the **mobile app** and the **paid web dashboard + cloud sync** (subscription, teams, PDFs, transcription, etc.). That is the full v1 offering we are designing toward.  
- **Phase 1 — build the mobile app first:** ship the Flutter app described in this document: free, local-first, no account required; zip export; works offline for capture and export. This is the **first delivery milestone** on the way to the MVP ([§13](#13-phasing--milestones)).  
- **Phase 2 — dashboard and sync:** ship **web dashboard**, **encrypted cloud sync**, **billing**, **team workspaces**, and the rest of the paid surface. This is the **second delivery milestone** and **completes the MVP**. Spec: [§17](#17-phase-2-dashboard-sync-subscription-and-teams). Work starts only after Phase 1 validates demand ([§14.5](#145-decision-gate)).  
- **Pricing principle:** the **app remains free** for anyone who uses it **without** turning on cloud sync. Paying is only for teams that want sync, the dashboard, and shared access—not for basic capture and zip export on-device.

### Implementation status (May 2026)

The repo matches the **Phase 1** architecture in broad strokes. Use this table when reading the rest of the doc — sections below still describe the **target** UX unless marked *implemented* or *partial*.

| Area | Status | Notes |
| --- | --- | --- |
| Flutter app (`app/`) | **Mostly built + M4 sync (partial)** | Phase 1 capture/export complete. **M3–M4:** sign-in, workspace switcher, bidirectional sync for jobs, notes, and **photo/voice/file blobs** (direct-to-MinIO). Pull-to-refresh + Settings sync with **last-sync footer** (subtle) and **snackbar feedback** on manual sync; persisted last-sync time per workspace; Wi‑Fi-only blob gate. Gaps: stretch business tags ([§7](#7-data-model)). |
| Landing (`landing/`) | **Active** | PHP + SQLite waitlist on jobsiterecords.com, plus SEO guides, use cases, trades, answers, and examples — not a single static page ([§14.4](#144-the-landing-site)). |
| Backend (`services/api/`) | **Partial (M1–M4)** | Go API + Postgres + **MinIO** in Docker Compose: **email + password auth**, **email magic link**, **Google OAuth** (ID token verify + `user_oauth_identities`), password reset via SMTP, workspaces, jobs/items sync, **media_files** mint/complete/download, lazy thumbnails. **Sign in with Apple** not started. Reports/billing not started. |
| Web dashboard (`web/`) | **Partial (M0–M4)** | Next.js shell + auth BFF + jobs list/detail with **day-grouped photo grid**, compact rows for voice/notes/files, **lightbox with prev/next + caption edit**, **photo annotation** (display + full editor: pen/line/arrow/circle/box/text, save overlay + render; mobile sync fixes for `annotation_overlay` / `annotated_render` roles). Tags, soft-delete, full job edit still partial. Spec: [`web-dashboard-design.md`](web-dashboard-design.md); annotation plan: [`web-photo-annotation-plan.md`](web-photo-annotation-plan.md). |
| Production deploy | **Scaffolded** | `docker-compose.deploy.yml` — `web`, `api`, Postgres, MinIO behind host **Traefik** (`tls=true` + `letsencrypt` per router); `landing/` stays separate. DNS: **A** records for `api`/`media`/`app` to the VPS. See [`deploy/README.md`](../deploy/README.md). |
| Tests | **Minimal** | `note_markdown_test.dart`, `photo_annotation_test.dart`; golden/integration tests not yet written ([§11.3](#113-testing)). |
| i18n / dark theme | **Not started** | English strings inline; light theme only ([§4](#4-platform--tech-stack), [§10](#10-visual-design)). |

**Phase 2 milestone progress ([`web-dashboard-design.md` §17](web-dashboard-design.md#17-milestones-user-testable-states)):** M0–M1 done; M2/M3 largely done; **M4 in progress** (blob sync API, mobile upload/pull, web media timeline). M5+ (teams, reports, billing) not started.

**Phase 1 milestone progress ([§13](#13-phasing--milestones)):** M0–M3 largely complete in code; M4 (polish, accessibility, golden tests, store assets) still in progress.

---

## 1. Product Overview

Contractors are not lacking ways to take photos or notes. They are lacking a **simple job-centered record system**. Today that information is scattered across camera roll, Google Photos, cloud folders, texts, paper notes, spreadsheets, invoice tools, CRM/PM tools, and memory.

Job Site Records is **not** a photo app. It is a **lightweight, offline job timeline** for photos, voice notes, text notes, files, tags, and exports — organized by job.

The product centers on a **mobile app** that helps contractors capture and retrieve field records without paperwork or cloud setup; the **MVP** also includes the **Phase 2** **web dashboard** and **cloud sync** for teams who subscribe ([§2](#2-goals--non-goals)). Users create a job folder, capture photos/voice/text/files, add captions and tags, browse a chronological timeline, and export a tidy zip archive when they need a clean handoff.

The core loop stays **shallow**: open app → pick job → tap photo / note / voice / file → save → done. Optional cloud (Phase 2) must not crowd that path for local-only users.

**Phase 1** (first ship) is the **mobile app alone**: **free, local-first, no account**. Job content is stored on the device and is not synced to our servers. Sharing is through the OS share sheet (email, SMS, AirDrop, WhatsApp, Drive, etc.) when the user chooses. Phase 1 **includes importing existing PDFs and files** into the job timeline ([§6.6a](#66a-capture-file--pdf-upload)) but does **not** include **PDF report generation** — that ships with the **Phase 2** web dashboard.

**Phase 2** (second ship) delivers the rest of the **MVP**: an optional **paid subscription** (per team / workspace, not per phone) that unlocks **cloud sync**, the **web dashboard**, **team collaboration** on the same jobs and items, and Pro features (branded PDFs, transcription, etc.). The Phase 1 app is designed so Phase 2 layers on without re-architecting the core data model ([§12](#12-future-proofing-for-phase-2-paid-tier), [§17](#17-phase-2-dashboard-sync-subscription-and-teams)).

---

## 2. Goals & Non-Goals

### MVP (product scope)

The **MVP** is the **whole v1 product**: **(1)** the **mobile app** (with a permanent **free, local-only** path) and **(2)** the **paid** **web dashboard** + **cloud sync** + **team** workspaces and related Pro capabilities ([§17](#17-phase-2-dashboard-sync-subscription-and-teams)). We **build and ship** it in **two phases**: **Phase 1** = mobile app; **Phase 2** = dashboard and sync (plus billing, teams, PDFs, transcription, etc.). **We deliberately do not expand into adjacent categories** (scheduling, estimating, full CRM, etc.); out-of-scope lists in [§16](#16-out-of-scope-explicit) and [§17.6](#176-explicitly-still-out-of-scope-for-phase-2-v1-examples) are the default answer.

### Phase 1 goals (mobile app — first delivery)

- **Speed above all:** the capture loop must beat or match camera roll and “text yourself a note.” Target flow: open app → pick job → tap photo / note / voice / file → save → done. If capture feels slower than alternatives, users will not adopt it ([§3.6](#36-mvp-feature-priorities)).
- **Ease + focus:** job → capture → export in **few steps** (target: useful first save **without onboarding**); **one primary action** per screen where practical; defaults reduce taps.
- One-tap capture loop on a job site (photo → caption → tag → voice note → save).
- Organize captures per **Job** with a chronological timeline grouped by date (natural daily log — not formal daily-report software).
- Export selected items as a shareable **zip archive** (photos, voice notes, notes, files, plus a human-readable index).
- **Offline-first** for the core workflow: capture, browse, and zip export work without an account or our cloud. No login or signup in Phase 1.
- Fast, robust, glove-friendly UI suitable for outdoor / job-site use.
- Cross-platform (Android + iOS) from a single codebase.
- **Validate demand.** A solid Phase 1 release is the market test for funding **Phase 2** ([§17](#17-phase-2-dashboard-sync-subscription-and-teams)). We need to learn whether contractors will install, use, retain, and ask for more — while keeping the free local path simple and proportionate ([§8.2](#82-privacy--security)).

### Phase 1 non-goals (not in the first mobile ship)

- **No PDF report generation in the app.** Branded PDF *exports* ship with the Phase 2 web dashboard. **Importing** existing PDFs (quotes, permits, receipts) **is** in Phase 1 scope ([§6.6a](#66a-capture-file--pdf-upload)).
- No cloud sync, no accounts, no multi-device (in Phase 1).
- No team collaboration / sharing inside the app (in Phase 1).
- No **cloud** AI (server transcription, summarization) in Phase 1. **Automatic** on-device voice-to-text is also **out of scope for Phase 1** — Android's system `SpeechRecognizer` holds the mic exclusively (it can't run alongside `MediaRecorder`), file-based recognition is unreliable across OEMs, and playback-into-mic workarounds make the device beep / dim media volume in ways field users will not tolerate. Users who want spoken words as text add a **text note** (OS keyboard dictation) alongside or instead of a voice clip.
- No web app in Phase 1.
- No in-app analytics SDKs or third-party tracking in the Phase 1 app (see [§8.2](#82-privacy--security) for what we do and don't collect).

### Phase 2 goals (dashboard, sync, and paid tier — second delivery; completes MVP)

Phase 2 is **out of scope for the Phase 1 milestone**; it is the next delivery phase once the decision gate in [§14.5](#145-decision-gate) is met. Headline capabilities:

- **Scope discipline:** ship **sync, dashboard, teams, PDF, transcription** — not a general contractor platform. Default answer to new ideas is **no** unless they serve that core; defer rest to [§17.6](#176-explicitly-still-out-of-scope-for-phase-2-v1-examples) / later.
- **Paid subscription** unlocks **cloud sync**, the **web dashboard**, and **team workspaces** (multiple users on one subscription share access to jobs, timeline items, and notes). The **mobile app stays free** for local-only use ([§17](#17-phase-2-dashboard-sync-subscription-and-teams) for full definition).
- Optional sign-in (only when the user or org opts into Pro): **email + password**, **magic link**, and **Google** today; **Apple** when shipped ([§17.9](#179-authentication-sign-in-methods)).
- Encrypted cloud backup + multi-device sync for subscribed workspaces.
- **Web dashboard** with the same data as synced devices — this is where **PDF report generation** lives (branded, with logo / header / footer / templates).
- Voice-note **transcription**: sound recordings are turned into **text notes** (auto-generated, editable) so timelines, item detail, and reports are **easy to read and search** without playing every clip; AI summaries per job / per day (server-side, queued).
- **Team model:** one **workspace** (company / crew) billed as a unit; **members** invited by email; MVP roles are **Owner** and **Member** only — members edit only **assigned** jobs and see the rest read-only. Admin / Viewer / Client roles are out of MVP scope (see [`web-dashboard-design.md` §6, §19](web-dashboard-design.md#19-decisions--open-questions)).

---

## 3. Target User, Problem & Positioning

**Primary user:** independent contractors and small crews (remodel, plumbing, electrical, framing, landscaping, painting, etc.) who need a **field record** for clients, change orders, disputes, invoicing follow-up, or their own memory — **not** another full CRM. Default flows assume **rushed, one-handed use**; anything that reads like IT admin belongs off the critical path or in Phase 2 settings only.

Many already use QuickBooks, Jobber, Buildertrend, spreadsheets, or paper for billing and scheduling. They want something simpler on site: job number / PO, notes, images, PDFs, files, daily record, easy retrieval.

### 3.1 Core problem

Contractors already capture job information constantly. The pain is that it lives in **too many places** and lacks **job context**. Job Site Records gives them one lightweight, offline job timeline instead of reconstructing what happened from camera roll + texts + paper later.

### 3.2 Main pain points (research summary)

| # | Pain | Current behavior | Product implication |
| --- | --- | --- | --- |
| 1 | **Job photos get lost in the camera roll** | Take photos on phone; maybe albums or Drive; search later under pressure | Job-based photo capture should be the **default**, not something organized after the fact |
| 2 | **Photos alone are weak proof** | Client asks when work was done; covered-up work is hard to prove | Emphasize **timestamped timeline**, captions, tags, job name/client/address, exportable record (future: visible timestamp/job overlays) |
| 3 | **Notes are scattered and forgotten** | Apple Notes, paper, texts, spreadsheets, invoice notes, memory | **Notes are first-class** — text, voice, captions, tags, job-level notes, all under the same job |
| 4 | **Voice notes fit field workflow** | Typing is slow with gloves; details forgotten before written down | Voice notes are a **core capture method** — open job, record, save to timeline, optionally tag (Phase 2: transcription) |
| 5 | **Contractors want job tracking, not another CRM** | Existing PM tools: too much setup, too many fields, too expensive, weak for field crews | Position as **not a CRM** — just the job record (job #, notes, images, files, export) |
| 6 | **File upload/import matters** | PDFs, receipts, permits, change orders live in email, Drive, texts, paper | App is a **job folder**, not only a capture tool — import files, attach to timeline, include in zip export |
| 7 | **Scope, change orders, disputes drive real value** | Client assumes work was included; small extras forgotten; weak documentation delays payment | Tags support business outcomes (Before, Issue, Change Order, Follow-up, etc.); defensible timeline without formal reports |
| 8 | **Daily logs are useful but formal daily-report software is heavy** | Paper logs get lost; office reconstructs later | **Natural timeline by date** — “today on this job” — plus export by date range; do not lead with “daily reporting software” |
| 9 | **Alternatives are fragmented** | Camera roll (easy, chaotic), Drive (flexible, manual), CompanyCam (strong but costly), full PM suites (broad, heavy) | Wedge: between **messy camera roll / notes app** and **expensive full PM platform** |
| 10 | **Contractors are allergic to generic SaaS pitches** | Subscription fatigue; skepticism toward validation posts; fear of overcomplicated software | Marketing: plain, contractor-centered — **free offline job notes, no account, no cloud required, export when you need it** |

### 3.3 Competitive wedge

```
  Messy camera roll / notes / texts          Job Site Records          Full CRM / PM (Jobber, Buildertrend, …)
  ─────────────────────────────────          ────────────────          ─────────────────────────────────────
  Easiest capture, no job context            Job-native timeline       Invoicing, scheduling, teams, $$$ 
  Personal photos mixed with job photos      Offline, free, fast         Too much setup for “just document”
  No export / proof bundle                   Zip + index when needed   Solves billing, weak on field record
```

**CompanyCam** and similar photo-first tools validate demand for job photos but may be too much or too costly for solo operators and handymen. **QuickBooks / invoice apps** are good for billing, weak for field records. Our lane is **narrow and fast**.

### 3.4 Positioning & messaging

**Primary headline:** Job notes, photos, and files — organized by project.

**Subheadline:** A free offline field record for contractors. Capture photos, voice notes, text notes, tags, and attachments on the job, then export a clean record when you need it.

**Short version:** Not a CRM. Not estimating software. Just the job record.

**Pain-based hooks (landing, store, community posts):**

- Stop digging through your camera roll.
- Stop losing job notes in texts and paper.
- Keep photos, notes, receipts, and files under the right job.
- Create a clean record when a client asks what happened.
- Document issues, follow-ups, and change-order context before you forget.

**Avoid sounding like:** AI-powered contractor productivity SaaS; all-in-one business management platform; revolutionary workflow automation. Reddit and trade forums punish promotional “I built an app” posts — lead with **free tool + feedback**, not subscription pitch ([§14.3](#143-distribution-plan)).

### 3.5 Key use cases

1. *Progress documentation* — "before / during / after" photos for the client.
2. *Issue / problem evidence* — water damage behind a sink, hidden conditions, etc.
3. *Change-order justification* — visual + verbal proof of scope changes.
4. *Daily record* — what got done today on this job (timeline by date, not a formal daily report).
5. *Handoff / dispute record* — zip (Phase 2: PDF) sent when the client asks what happened or payment is disputed.
6. *Job file folder* — attach estimate PDF, signed quote, receipt, permit, inspection report, delivery ticket, client-provided photo, screenshot of a text.

### 3.6 MVP feature priorities

Aligned with Phase 1 mobile scope ([§13](#13-phasing--milestones)). “Must-have” matches what we ship first; “strongly consider” is the next cut before M4 if capture speed stays intact.

**Must-have (Phase 1 core)**

- Create job
- Add photo (camera + gallery import)
- Add text note
- Add voice note
- **Upload PDF / file** — attach existing documents to the job timeline ([§6.6a](#66a-capture-file--pdf-upload))
- Add caption
- Add tags — including default **`Receipt`** for material runs, supplier invoices, and scanned/uploaded receipts ([§7](#7-data-model))
- Timeline grouped by date
- Search jobs
- Export zip with photos, notes, files, timestamps, tags, and `index.html`

**Strongly consider for MVP (Phase 1 stretch)**

- Import image files alongside PDFs (same picker flow; images saved as `kind = file`, not as camera photos)
- Tag files and notes with business-oriented categories
- **“Today”** section or pin at top of job timeline (same date grouping, faster scan)
- Additional default tags: Follow-up, Material, Change Order, Client Request (see [§7](#7-data-model))
- **Formatted text notes** — WYSIWYG editor with bold, italics, and bullet lists ([§6.6](#66-capture-text-note))
- **Photo annotation** — pen, straight line, arrow, circle, and rectangle in a few high-contrast colors so contractors can mark up site photos directly (“circle the cracked tile”, “arrow at the leak”) without leaving the app ([§6.4a](#64a-photo-annotation-mark-up))

**Defer (Phase 2 or later)**

- AI summaries
- Invoicing / estimates
- Advanced CRM features (scheduling, payments, client portal)
- Visible timestamp/job overlays on photos (nice future; timeline + metadata suffice for MVP)
- Formal daily-report templates

---

## 4. Platform & Tech Stack

**Implemented today** (`app/pubspec.yaml`):

- **Framework:** Flutter (Dart 3.9+) — single codebase for Android and iOS. Flutter SDK ≥ 3.41.
- **Min OS:** iOS 14+, Android 8.0+ (API 26). Android target SDK 34.
- **Local storage:** `sqflite` for metadata (schema version **2** — `media_files.original_filename`; default tags include **`Receipt`**); `path_provider` documents directory for media.
- **Camera:** `camera` for live capture; `image_picker` for gallery import on the photo review flow.
- **Audio:** `record` (v5.1.2) for capture, `just_audio` for playback. No dedicated waveform package yet — voice UI uses elapsed time + play/pause slider.
- **Voice transcription:** **not on the phone.** Voice items are audio + caption/tags only. Phase 2 adds optional **dashboard/cloud** STT after sync — no native hooks and no `transcript` column in the local `items` table ([§17.7](#177-voice-transcription-as-readable-notes-phase-2)).
- **Zip export:** `archive` (pure Dart).
- **Rich text notes:** `flutter_quill` (WYSIWYG editor) + `markdown` / `flutter_markdown` (serialize to `items.body`, render read-only + export HTML).
- **Sharing / links:** `share_plus` for exports and single-item share; `url_launcher` for waitlist, feedback `mailto:`, and privacy policy URLs in Settings.
- **File / PDF upload (*implemented*):** `file_picker` + `open_filex` — copy selected files into app storage; no upload to our servers in Phase 1 ([§6.6a](#66a-capture-file--pdf-upload)).
- **State management:** **Riverpod** (`flutter_riverpod`).
- **Routing:** `go_router` with a 3-tab `ShellRoute` plus stack routes for job/capture/export/item flows.
- **Permissions:** `permission_handler` — requested when opening camera or starting voice record (no separate in-app rationale screen yet).
- **IDs / time:** `uuid` for entity IDs; `intl` for dates in export filenames and UI formatting.

**Planned, not in the tree yet:**

- **Localization:** `flutter_localizations` + ARB files under `lib/l10n/` (strings are hard-coded English for now).
- **Optional waveform UI:** e.g. `audio_waveforms` — deferred; current player is sufficient for Phase 1.

> Rationale for Flutter: single codebase, strong camera/media plugin ecosystem, good performance for image-heavy UIs, easy to ship to both stores from one repo.

---

## 5. Information Architecture

Bottom tab bar (3 tabs):

1. **Jobs** — list of all jobs (default landing screen).
2. **Capture** — quick-capture entry. **Implemented:** lists jobs, then a bottom sheet to pick Photo / Voice / Text for the chosen job (does not open the camera until a job is selected). **Target:** optional direct camera when a “current job” context exists; add **File / PDF** to the mode sheet ([§6.6a](#66a-capture-file--pdf-upload)).
3. **Settings** — storage info, tag library, waitlist link, feedback, about, privacy.

**Three tabs on purpose:** daily work is **Jobs + Capture**; Settings and per-job export are secondary.

**Android system back (*implemented*):** Tab bar uses `StatefulShellRoute.indexedStack`. On **Capture** or **Settings**, system back switches to **Jobs** via `AppBackHandler` (`WidgetsBindingObserver.didPopRoute` → `router.go('/jobs')`) so the app does not call `SystemNavigator.pop` when go_router’s `popRoute` misses branch-level `PopScope`. `SecondaryTabBack` (`PopScope` on tab roots) remains as a secondary guard. `android:enableOnBackInvokedCallback="false"` on `MainActivity` uses the legacy back key path on MIUI. Deeper routes on the root navigator still pop normally.

> No standalone "Reports" tab in **Phase 1**. Exporting is initiated from inside a job ("Export…" / "Share Job"). When the **Phase 2** web dashboard ships, that's where reports / PDFs are produced and managed.

Primary navigation flow:

```
Jobs
 └─ Job Detail (timeline of items, grouped by date; "Today" pinned when applicable)
     ├─ Item Detail (photo / voice / note / file + caption + tags)
     │   └─ Edit / Delete / Share single item
     ├─ Add Photo, Note, Voice, or File  ──►  Capture / import
     │   ├─ Photo mode (camera or gallery)
     │   ├─ Voice Note mode (recorder)
     │   ├─ Text Note mode
     │   └─ File mode (document picker — **PDF** primary; images and other formats optional)
     ├─ Select items… (or long-press row)  ──►  Check timeline  ──►  Delete (N)  (bulk delete on device)
     └─ Export…  ──►  Select items  ──►  Options  ──►  Share (zip via OS share sheet)
```

---

## 6. Screens (Phase 1 mobile app)

Screen specs derived from the mockups in `/docs`.

### 6.1 Jobs (Home)
- Header: app title, "+" button to create a new job.
- Search field; optional filter chip ("All Jobs", "In Progress", "Completed").
- List rows: thumbnail (most recent photo or placeholder), job name, address, status badge, item count, "Updated X ago".
- Tap row → Job Detail. Long-press → quick actions (rename, mark complete, delete).
- Footer reminder (local-only use): *"Job data is stored on this device."* — accurate for unsynced use; export/share is always the user's choice via the OS ([§8.2](#82-privacy--security)).

### 6.2 New / Edit Job
- Fields: Name (required), Client name, Address, Job number (optional), Start date, End date / target, Notes, Status (`Planning` / `In Progress` / `Completed`).
- **Address (*implemented*):** when online and `GOOGLE_MAPS` is set in `app/.env`, the address field uses the native **Google Places SDK** (New API) for street-level autocomplete (worldwide search, biased toward device location when permitted). Requires **Places API (New)** + **Maps SDK for Android** enabled on the key. Manual entry still works without picking a suggestion.
- "Create" returns to Job Detail.

### 6.3 Job Detail
- Header: back, job name, address, status pill, edit button, overflow menu.
- Summary chips: total items, photos, voice notes, notes, files, issues (counts).
- Tabs or sections: **Timeline** (default), **Notes**, **Details**.
- Timeline: grouped by date (newest first). When the job has captures **today**, show a **Today** section at the top (same rows as date grouping — not a separate data model). Each row = thumbnail/icon + time + caption preview + tag chips + overflow menu.
- **Timeline filter/search (*implemented*):** collapsed by default — app bar **search** icon expands the filter panel (search field, type chips, tag chips). When filters are active and collapsed, a **summary bar** shows the current filters (e.g. `“leak” · Photos · Issue`) with clear; tap the bar to expand again. Search matches caption, note body, imported **filename**, and tag names (case-insensitive). Type chips filter by photo / voice / note / **file** (multi-select, OR). Tag filter: quick chips for tags used in the job (first six) plus **Tags** sheet for searchable multi-select when many tags exist; selected tags use OR semantics. Count chips stay at job totals; timeline header shows “N of M” when filters are active. Export and bulk select still operate on the full job.
- Floating "+ Add" CTA (photo, voice, text, file — sheet or speed-dial; keep one obvious primary action).
- Overflow: **Select items…**, Export…, Mark Completed, Delete Job.
- **Bulk select (*implemented*):** overflow **Select items…** or **long-press** a timeline row enters selection mode (checkboxes, nothing pre-selected). App bar shows count + **All**; bottom **Tag (N)** + **Delete**; FAB hidden while selecting. **Back** exits selection (does not leave the job). Single-item edit/delete remains on Item Detail.
- **Bulk tags (*implemented*):** in selection mode, **Tag** opens a bottom sheet with tri-state tag chips (off / partial / all selected items). Tap toggles the tag on all selected items in a local preview; **Done** applies adds/removes to the database. Dismiss without **Done** discards changes. Reuses the tag library and **Add tag** flow from capture.

### 6.4 Capture (Photo) — batch-first (*implemented*)

The default photo flow is **batch-first**: walk a room, roof, unit, or phase shooting rapidly; tag and caption **once** when you stop.

1. Open job → **Photos** (or Capture tab → job → Photos) → full-screen camera.
2. Tap shutter repeatedly — camera stays open; a strip shows count and the latest thumbnail.
3. **Done** → batch review: grid of thumbnails (remove individual shots if needed), optional shared caption (“What does this batch show?”), tag chips applied to **every** photo in the batch.
4. **Save** writes one timeline item per photo (each keeps its shutter timestamp); shared caption and tags copy to all.

Camera controls: flash toggle, lens swap, gallery import (adds to the current batch), undo last shot. Back with unsaved photos prompts discard. Single-photo batches use the same flow (shoot once → Done → tag → Save).

**Not in Phase 1 UI:** zoom presets; inline voice note on the photo review screen (voice remains a separate capture kind; repo still supports attaching voice to a photo item).

- Saves into the currently open job. If none, asks to pick or create one.

### 6.4a Photo annotation (mark-up)

**Phase 1 — implemented** (Item Detail → **Annotate**). **Phase 1 v2 — implemented** (batch-review annotate + text labels). Job photos often need a visible pointer (“circle the cracked tile”, “arrow at the leak”, “line along the crack in the slab”). Without it the timeline reader has to guess what the photo is meant to show, and contractors fall back to editing in a separate app or losing the context entirely. Code: `app/lib/features/photo_annotation/`, overlay JSON + flatten in `app/lib/domain/services/photo_annotation_renderer.dart`.

**Entry points (same editor):**

1. **Item Detail (photo)** → **Annotate** action — primary path, used after a photo is saved.
2. **Photo capture batch review** (§6.4) → tap a thumbnail → **Annotate** before Save — useful when the contractor knows immediately which shot needs a circle. **Implemented.**

**Tools (v1):**

- **Pen** — free-hand stroke; one medium thickness.
- **Straight line** — drag from start to end.
- **Arrow** — straight line with an arrowhead at the end point (the most common ask: “arrow at the leak”).
- **Circle / ellipse** — drag to size; outline only, no fill.
- **Rectangle** — outline only.
- **Color palette** — small fixed set tuned for visibility against typical job-site photos: **red, yellow, white, black, green** (5 swatches, single tap).
- **Undo / redo** — per-step (stack of strokes).
- **Clear all** — destructive, with confirmation.

**Tools (v2 — implemented):**

- **Text label** — tap to place; short label (e.g. “Leak here”) with semi-transparent background for readability on site photos. Stored as `type: "text"` with `p1` anchor + `text` in overlay JSON (document version 2).

Keep the toolbox shallow on purpose. **Still not planned:** blur / redact, crop, rotate, filters, stickers, measurement / dimension tools, callouts with leaders.

**Storage & data model:**

- **Original photo is preserved unchanged** at `media/<job_id>/<item_id>/photo.jpg` — annotations must never overwrite the source pixels.
- Strokes are saved as a small **vector overlay** (JSON: shape, color, points) at `media/<job_id>/<item_id>/photo.annotations.json` so re-opening the editor loads them as editable strokes.
- A **flattened render** is also written to `media/<job_id>/<item_id>/photo.annotated.jpg` for fast timeline display and for zip export (so receivers see the markup without our app).
- `MediaFile.role` gains two new values: `annotation_overlay` (vector JSON) and `annotated_render` (flattened JPEG). The existing `primary_photo` row is untouched. No new tables.

**Display & export:**

- Timeline and item detail show the **annotated** render when present; otherwise the original.
- Item Detail offers a long-press / toggle to peek the **original** underneath.
- Zip export ([§9](#9-export--sharing)) places the **annotated** JPEG in `photos/` so external viewers see the markup. When an annotation overlay exists the original is also included alongside under the same date prefix with an `.original.jpg` suffix, so the contractor still has the unedited shot in the handoff bundle.
- `index.html` shows the annotated render and links to the original when present.

**Scope limits (Phase 1):**

- **Photo only.** No PDF annotation; no annotating images imported via §6.6a (those open externally with the OS viewer).
- **Private mark-up layer.** Annotation is for the contractor’s own record / client conversations — not a client-review workflow with separate “client view” vs. “contractor view” of the same photo.
- **No automatic detection.** No AI / OCR / object-detection; the contractor draws what matters.

### 6.5 Capture (Voice Note)
- Large centered waveform + elapsed time.
- Big record / pause / stop control. Cancel and save (check) actions.
- Optional caption field below.
- A voice note can be attached to a photo, or stand on its own.
- **Implemented (Phase 1):** record audio, optional caption and tags; item detail shows **player**, caption, and metadata. No transcript on device — use a **text note** for dictated/written text. Phase 2 transcription is **dashboard-only** ([§17.7](#177-voice-transcription-as-readable-notes-phase-2)).

### 6.6 Capture (Text Note)
- Multi-line note with optional caption and tags.
- **Formatted note editor (*implemented*):** contractors work in a **visual editor** — bold looks bold, bullets look like bullets. They must **never** see or edit raw markdown, HTML, or other markup syntax. Toolbar: **B**, *I*, and bullet list only (plus undo/redo). Implemented with `flutter_quill` in `app/lib/features/capture/widgets/note_editor.dart`; markdown serialization in `app/lib/core/note_markdown.dart`.
- **Supported formatting (v1):** **bold**, **italics**, and **bullet list** only. No headings, numbered lists, or nested-list controls.
- **Capture & edit:** New Note and Item Detail **Edit** use the **same WYSIWYG editor** — no separate “preview” or “source” mode. Read-only Item Detail shows the formatted body; tapping **Edit** opens the editor with formatting intact.
- **Storage (internal):** on save, serialize the document to **markdown** in `items.body` ([§7](#7-data-model)) — **no schema change**. Markdown is an implementation detail for export, search, and future sync; the app loads it back into the editor on open. Existing plain-text notes open as unformatted paragraphs (no migration). Caption stays single-line plain text.
- **Export:** `index.html` and per-note files in the zip ([§9](#9-export--sharing)) render the stored markdown to HTML so handoffs match what the user saw in the app.
- **Scope limits (Phase 1):** no headings, numbered lists, tables, embedded images, hyperlinks, code blocks, footnotes, font picker, colors, or alignment controls. Not a word processor — if users need a richer document, they import a PDF ([§6.6a](#66a-capture-file--pdf-upload)). Legacy notes that already contain headings or numbered lists still **display** correctly; re-saving normalizes toward the supported subset when edited.

### 6.6a Capture (File / PDF upload)

**Phase 1 — implemented.** Contractors already have PDFs in email, Drive, and texts; the app accepts them into the job folder without turning into a document manager.

**Primary use case:** attach an **existing PDF** (or other file) to the current job — estimates, signed quotes, permits, inspection reports, change orders, receipts, delivery tickets.

**Entry points (same flow):**

1. Job Detail → **+ Add** → **File / PDF**
2. Capture tab → pick job → mode sheet → **File / PDF**
3. OS **Share into app** (stretch) — receive a PDF from Mail/Drive/Files and pick which job to attach it to

**Flow:**

1. System document picker opens (`file_picker` or platform equivalent). **Default filter:** PDF (`application/pdf`). Optional “All files” for images and common office formats.
2. User selects one or more files (v1: **single file per save** is fine; multi-select can follow).
3. Optional caption + tags screen (same pattern as voice/text capture). **`Receipt` is in the default tag chip row** — one tap for material runs and uploaded/scanned receipts; user picks tags explicitly (no filename-based auto-tag in v1).
4. **Save** copies the file into app storage, creates an `Item` with `kind = file`, and shows it on the timeline.

**Storage & data model:**

- Copy into `media/<job_id>/<item_id>/` preserving original extension (e.g. `change-order-signed.pdf`).
- `MediaFile.role = file`, `mime_type` from picker or extension, `original_filename` for display and export naming.
- No cloud upload in Phase 1 — file stays on device like photos and voice notes.

**Timeline & detail UX:**

- Row: PDF icon (or generic file icon), original filename, time, caption preview, tag chips.
- Item detail: filename, mime type, size; **Open with…** via OS when user taps (no built-in PDF viewer required in Phase 1).
- Timeline type filter includes **Files**; search matches filename and caption.

**Export:**

- Included in zip under `files/` with dated, sanitized filename (see [§9](#9-export--sharing)).
- `index.html` lists file items with download links / icons (same as other attachments).

**Scope limits (Phase 1):**

- **Import only** — no in-app PDF editing, annotation, or merge.
- **No PDF generation** — that remains Phase 2 dashboard ([§2](#2-goals--non-goals)).
- Reasonable size cap (e.g. 25–50 MB per file) with a clear error if exceeded; exact limit TBD at implementation.
- Password-protected PDFs: store and export as-is; no unlock UI in v1.

**Supported types (v1):**

| Priority | MIME / extension | Notes |
| --- | --- | --- |
| **Must** | `application/pdf` (`.pdf`) | Primary target — quotes, permits, COs, receipts |
| Should | Common images (`.jpg`, `.png`, `.heic`) | Client-provided photos, scanned receipts — saved as `file`, not camera `photo` |
| Later | `.doc`, `.docx`, `.xls`, `.xlsx`, `.txt` | Same picker path; lower priority than PDF |

**Examples:** estimate PDF, signed quote, permit, inspection report, change order, delivery ticket, **receipt** (PDF or photo — tag **`Receipt`**).

**Receipt tagging:** Contractors photograph or import receipts constantly (Home Depot runs, fuel, subs). The default **`Receipt`** tag lets them filter the timeline to “everything I spent on this job” and include those items in zip exports for bookkeeping or dispute follow-up. Applies to:

- PDF receipts from email or supplier portals (file upload)
- Photos of paper receipts (camera or gallery — same tag, no special item kind)
- Imported receipt images (`.jpg` / `.png` via file picker)

**Future (post-MVP dashboard):** OCR on **`Receipt`** items rolls up job costs and exports to CSV/Excel — see [§17.8](#178-receipt-ocr--job-expenses-post-mvp-dashboard).

### 6.7 Item Detail
- Large media area (photo, audio player, file type icon + filename, or note body).
- For photos: pinch-zoom, swipe between items in the same job. When an **annotation overlay** exists ([§6.4a](#64a-photo-annotation-mark-up)), the view shows the annotated render by default; a long-press / toggle peeks the original underneath. An **Annotate** action opens the mark-up editor with existing strokes loaded as editable shapes.
- For text notes: read-only view shows **formatted** body ([§6.6](#66-capture-text-note)) — bold, italics, bullet lists. **Edit** opens the same WYSIWYG editor (not raw markup); tags and caption stay on the same screen.
- For files: show name, mime type, size; open via OS “Open with…” when user taps (no built-in PDF viewer required in Phase 1).
- Below: timestamp, caption, tag chips, optional voice note player, free-text note.
- **Voice items (*implemented*):** audio player, caption, tags. Transcription deferred to Phase 2 **web dashboard** ([§17.7](#177-voice-transcription-as-readable-notes-phase-2)). Photos/notes/files unchanged.
- Actions: Share (single item), Add to Export, Edit, **Annotate** (photo only), Delete.

### 6.8 Export (Share Job)
A lightweight 2-step sheet, not a full multi-screen wizard. Reachable from the Job Detail overflow menu and from item multi-select.

- Step 1 — Select items (checkbox list grouped by date with thumbnails; "Select all" by default). Selected count in footer.
- Step 2 — Options + Share:
  - Date range (optional override).
  - Sort order (oldest first / newest first).
  - Include captions, tags, timestamps, notes (toggles, all on by default).
  - Big **Share** button → builds the zip and opens the native share sheet.

> No PDF generation, no preview screen, no "saved reports" list in **Phase 1**. The zip is built on demand and handed to the OS share sheet; we don't keep a copy ourselves (kept transient in the app's cache dir and cleaned up).

### 6.9 Settings
- **Data & Storage**: total storage used, "Export all data" (zip backup of the whole DB + media), "Clear all data" (destructive, with confirmation).
- **Tags**: manage the default tag library (add, rename, delete, reorder).
- **Default Export Settings**: defaults for the toggles in the export sheet (sort order, what to include).
- **What's next** — a single, low-key row: *"PDF reports, web dashboard, cloud sync coming soon. Get notified →"* opens an external waitlist form (see §14). This is the most important validation signal we have. No nagging banners elsewhere.
- **Send feedback** — opens a `mailto:` to a dedicated address. No in-app form, no backend.
- **About**: app version, open-source licenses, privacy policy, terms.

### 6.10 Implementation gaps vs target (Phase 1)

Screens in §6.1–6.9 are the **design target**. The shipped app (`app/lib/features/`) implements most of the core loop with these differences:

| Area | Target (§6) | Current code |
| --- | --- | --- |
| Jobs list | Filter chips (All / In Progress / Completed) | Search only; status shown per row, no filter chips |
| Jobs list | Long-press quick actions | Tap only; edit/delete via Job Detail |
| Job detail | Tabs: Timeline / Notes / Details | Single scroll: header, count chips, **collapsible filter/search**, timeline by date |
| Job detail | Timeline search / filter | **Implemented** — app bar search toggles panel; active-filter summary when collapsed; type/tag/full-text search |
| Job detail | Row overflow menus | **Bulk select**, **tag**, and **delete** on timeline (overflow + long-press); no per-row overflow |
| Job detail | Status pill in header | Status on list card; job notes field on edit form only |
| Capture tab | Open camera directly | Job picker → mode sheet → capture route |
| PDF / file upload | Document picker → copy to app storage → timeline item (`kind = file`) | **Implemented** — `FileCaptureScreen`, `ItemsRepository.createFile`, route `capture-file` |
| Photo annotation | Pen / line / arrow / circle / rectangle / text label; vector overlay + flattened render; Item Detail + batch-review entry | **Implemented** |
| Text note formatting | WYSIWYG editor (bold / italics / bullet list); markdown serialized in `items.body` | **Implemented** — `NoteEditor` + `NoteBodyView`; export renders markdown to HTML |
| Default tags | **`Receipt`** + progress/status set (see [§7](#7-data-model)) | **Implemented** — `Receipt` seeded on fresh install; v2 migration inserts if missing |
| Job detail | “Today” section when captures exist today | Date grouping only |
| Photo capture | Batch-first: rapid multi-shot, tag at end | **Implemented** — continuous camera, Done → shared caption/tags; per-photo timestamps |
| Photo capture | Inline “tap to record” voice on photo | Voice is a separate item kind (repo supports attaching voice to photo, UI does not expose it yet) |
| Photo capture | Zoom presets | Flash toggle + camera swap + gallery import |
| Item detail | Open file via OS | **Implemented** — `open_filex` on tap; image files show inline preview |
| Item detail | Pinch-zoom; swipe between items in job | Single item view; share / edit / delete |
| Item detail | Waveform for audio | Play/pause + seek slider (`just_audio`) |
| Item detail | Voice transcript below player | **Out of scope** — Phase 2 transcription is dashboard/cloud only; use text notes on device |
| Export | 2-step sheet | Full-screen route: options + checklist on one page |
| Settings | Export all data; default export prefs; terms | Storage used, clear all, inline tag add/delete (no rename/reorder), waitlist → `https://jobsiterecords.com/`, `mailto:feedback@jobsiterecords.com`, privacy URL |
| Permissions | In-app rationale before OS dialog | OS dialog on first camera/mic use |
| Performance | ~512px timeline thumbnails | Timeline uses full-resolution files from disk (no separate thumb files yet) |

---

## 7. Data Model

All entities live in a single local SQLite database. Media files live on disk; the DB stores their paths.

```
Job
  id (uuid, pk)
  name
  client_name?
  address?
  job_number?
  status            (planning | in_progress | completed)
  start_date?
  end_date?
  notes?
  cover_item_id?    (fk Item — chosen thumbnail)
  created_at
  updated_at

Item                (a single timeline entry)
  id (uuid, pk)
  job_id (fk Job)
  kind              (photo | voice | note | file)
  caption?
  body?             (text note content — plain text today; markdown serialized from WYSIWYG editor, §6.6)
  captured_at       (defaults to created_at; user can edit)
  created_at
  updated_at

MediaFile
  id (uuid, pk)
  item_id (fk Item)
  role              (primary_photo | voice_note | attachment | file
                     | annotation_overlay | annotated_render   — §6.4a)
  relative_path     (under app documents dir)
  mime_type
  width?
  height?
  duration_ms?
  size_bytes
  original_filename?  (for imported files — display + export naming)
  created_at

Tag
  id (uuid, pk)
  name              (unique, case-insensitive)
  color?            (optional hex)
  is_default        (bool, ships with the app)
  sort_order

  ItemTag             (join)
  item_id (fk)
  tag_id (fk)
  pk (item_id, tag_id)
```

> No `Report` table in **Phase 1**. Exports are built on demand and handed off to the OS share sheet; the app does not persist a list of past exports. This row reappears in the schema when the paid web dashboard ships and starts generating PDFs.

### Default tag set (seeded on first launch)

**Progress / status (*shipped*):** `Before`, `During`, `After`, `Completed`

**Business / proof (*partially shipped*):** `Issue`, **`Receipt`** (*shipped*); `Follow-up`, `Material`, `Change Order`, `Client Request` (*stretch — not seeded yet*)

| Tag | Color (hex) | Typical use |
| --- | --- | --- |
| `Before` | `#9CA3AF` | Pre-work condition |
| `During` | `#F59E0B` | Work in progress |
| `After` | `#10B981` | Finished state |
| `Completed` | `#3B82F6` | Milestone / sign-off |
| `Issue` | `#EF4444` | Problems, defects, hidden conditions |
| **`Receipt`** | `#14B8A6` | **Material runs, supplier invoices, photographed or uploaded receipts** ([§6.6a](#66a-capture-file--pdf-upload)) |
| `Follow-up` | `#A855F7` | Action needed later |
| `Material` | `#F97316` | Deliveries, stock on site (non-receipt proof) |
| `Change Order` | `#EC4899` | Scope-change evidence |
| `Client Request` | `#06B6D4` | Homeowner-directed work |

Each seeded tag gets its **color** in `tags.color` (UI uses chip styling). User-extensible via Settings (add custom tags; default tags cannot be deleted). Trade tags like `Plumbing`, `Framing`, etc. are not bundled by default — users add their own.

**Existing installs:** when `Receipt` (and optional stretch tags) ship, add a **schema v2 migration** that inserts missing default tags by name if absent — do not duplicate tags the user already created manually.

### File layout on disk
```
<app documents>/
  jobsiterecords.db
  media/
    <job_id>/
      <item_id>/
        photo.jpg                      (original — never overwritten)
        photo.annotations.json         (vector strokes — §6.4a)
        photo.annotated.jpg            (flattened render — §6.4a)
        voice.m4a
        thumb.jpg
        attachment.pdf                 (or original extension for imported files)
```

### Schema versioning
- **Current:** `AppDatabase` at schema **version 2** (`media_files.original_filename`; v2 migration adds **`Receipt`** tag on upgrade). The local `items` table does **not** include a `transcript` column (and never will for Phase 1).
- **Future (Phase 2 sync):** optional local columns only if sync requires them (e.g. `deleted_at`, remote ids). **Transcription text lives in the cloud** (dashboard / `services/transcribe/`), not as a field we pre-wire on the device.
- Each row carries `created_at`/`updated_at` so the future cloud-sync feature can layer a sync engine on top without changing the model.

---

## 8. Cross-Cutting Concerns

### 8.0 Scope & UX (guardrails)

- **Say no by default:** if it is not job-centered record capture (photos, voice, text, files, tags), organization per job, or handoff export (Phase 1) / sync + dashboard + PDF + teams (Phase 2), it probably does not ship ([§16](#16-out-of-scope-explicit), [§17.6](#176-explicitly-still-out-of-scope-for-phase-2-v1-examples)).
- **Plain + shallow:** short labels, **one primary action** per screen where practical, minimal onboarding; failures show **one clear next step** and never block capture on non-critical validation. Phase 2 sign-in and billing stay **off** the free local path ([§17](#17-phase-2-dashboard-sync-subscription-and-teams)).

### 8.1 Permissions
Asked **just-in-time**, never up front:
- Camera — first time the camera screen opens.
- Microphone — first time the user taps record.
- Photo library — only if/when the user imports an existing photo.
- Storage / documents — when the user first opens **File / PDF** import (Android scoped storage; iOS document picker does not require a separate library permission in most flows).

Each prompt is preceded by a one-screen rationale in the app's own UI so the OS dialog doesn't come out of context.

### 8.2 Privacy & Security

**Local-only use (no sync)** should be described honestly: normal mobile-app privacy, not a special guarantee.

- **Job content:** photos, voice, notes, and metadata live in the app's sandbox on the device. We do **not** upload or sync that content to our servers in Phase 1. Uninstalling the app removes it (subject to OS backup behavior the user may have enabled).
- **Sharing:** zip export and the OS share sheet send copies **where the user chooses** (email, Drive, WhatsApp, etc.). That is expected — we are not responsible for what happens after the user shares.
- **Optional links:** Settings may open the waitlist site, a `mailto:` feedback link, or a privacy policy URL in the browser. Those are separate from job data and only happen when the user taps them.
- **What we avoid in the app:** in-app analytics SDKs and third-party trackers in Phase 1. If we add crash reporting later, it should be opt-in and disclosed in the privacy policy.
- **What exists outside the app:** App Store / Play Console aggregate stats; voluntary waitlist signups on the website (email and form fields the user submits). Standard stuff — document it in the privacy policy rather than overclaiming in marketing.
- **Device security:** data stays in the app container like any other app. Optional biometric lock on open is a stretch goal for Phase 1.
- **Privacy policy:** linked from Settings (and the landing site); should match actual behavior for local-only vs Phase 2 sync.
- **Clear all data:** one destructive action in Settings; irreversible on device.

### 8.3 Performance & Reliability
- **Target:** photos downscaled for the timeline (cached thumbnails ~512px); originals kept full-resolution for export.
- **Current:** originals are written to `media/<job_id>/<item_id>/photo.jpg`; the timeline reads those files directly (no `thumb.jpg` cache yet).
- Audio is encoded to AAC / m4a, mono, ~64 kbps.
- All writes are transactional in SQLite. Media files are written to a temp path and atomically moved on success.
- Background-safe capture: if the app is killed mid-capture, the partial item is recovered on next launch.

### 8.4 Accessibility
- Minimum 44pt touch targets.
- Full screen reader labels (TalkBack / VoiceOver).
- Sufficient contrast in both light and dark themes.
- Captions and notes support large text scaling.

### 8.5 Internationalization
- All user-visible strings live in ARB files; English only at launch.
- Dates/times rendered via `intl` using the device locale.

---

## 9. Export & Sharing

**Phase 1**'s only export format is a **zip archive**. PDF generation is intentionally deferred to the **Phase 2** web dashboard, where it can be done with proper layout, branding, and on hardware that isn't a phone.

### Zip archive
A flat, human-readable structure so it's useful even outside the app:
```
JobSiteRecords_<JobName>_<YYYY-MM-DD>.zip
 ├─ index.html             (single-page summary — opens in any browser)
 ├─ photos/
 │   ├─ 2026-05-13_09-15_before_kitchen-demo.jpg            (annotated when overlay exists)
 │   └─ 2026-05-13_09-15_before_kitchen-demo.original.jpg   (only when annotations were added — §6.4a)
 ├─ voice_notes/
 │   └─ 2026-05-13_10-42_water-damage.m4a
 ├─ notes/
 │   └─ 2026-05-13_10-42.md           (markdown — bold / italics / bullets preserved, §6.6)
 └─ files/
     └─ 2026-05-13_14-30_change-order-signed.pdf
```

- `index.html` is a static, self-contained page with the job header, items grouped by date, captions, tags, `<audio>` tags for voice notes, and links/icons for attached files. Text notes are **rendered from markdown to HTML** during export so emphasis and bullet lists show up the same way they do in the app ([§6.6](#66-capture-text-note)). Photos with annotations are exported as the **flattened render**, with the **original** kept alongside under an `.original.jpg` suffix so the receiver gets both ([§6.4a](#64a-photo-annotation-mark-up)). No JS, no external assets. This is the human-friendly "report" view — good enough for **Phase 1**, and viewable on any device the user shares the zip to. No CSV or JSON sidecars — contractors hand off folders clients can open, not data files for spreadsheets or tooling.

### Native share
`share_plus` invokes the OS share sheet so the user can pick email, SMS, AirDrop, WhatsApp, Drive, Files, etc. The generated zip lives in the app's cache directory and is purged after the share completes (or on next launch).

---

## 10. Visual Design

**Phase 1 choice (implemented):** **light theme + warm amber accent** — see `app/lib/app/theme.dart` (`AppColors.accent` `#F59E0B`, light gray surfaces, Material 3). Matches the friendly SMB direction from mockups 1 and 4.

**Deferred:** industrial dark + orange ("BUILT" mockup) and **dark mode** — only `buildLightTheme()` is wired in `main.dart` today. A future `AppTheme` token file can add dark mode without touching feature screens.

> Note: the mockups show PDF previews and a "Reports" tab. Those screens are aspirational — they correspond to the **Phase 2** web dashboard and are not part of **Phase 1** scope. Use them for visual language (typography, spacing, tag chips, timeline grouping) only.

Typography: system/Material defaults for now; target a single clean sans-serif (e.g., Inter) at three sizes. Generous spacing. Photos are the hero — chrome stays out of the way.

Iconography: filled tab-bar icons (`NavigationBar`), outlined action icons. Tag chips are rounded pills with amber highlight when selected.

Theming: centralize tokens in `app/lib/app/theme.dart`; add dark palette when needed.

---

## 11. Repository & Code Architecture

### 11.1 Repository layout (monorepo)

The repository is a **monorepo from day one**, sized for the long game. **Phase 1** ships only the Flutter app first, but the **MVP** includes dashboard + sync in **Phase 2**; the repo assumes Job Site Records may grow into a full SaaS (mobile + web + backend services). No code lives in the root — only folders, top-level config, and meta files.

```
/                         (repo root — no application code)
├── app/                  Flutter mobile app (Phase 1) — active
├── landing/              Marketing site + waitlist (PHP + SQLite) — active
├── services/             Backend services — placeholder until Phase 2 (see §11.4)
├── docs/                 Design docs, mockups, MVP brief
├── README.md             Repo overview and per-folder pointers
├── LICENSE
├── .gitignore
└── .editorconfig
```

Optional: `private/` at repo root (or on server beside `landing/`) holds `subscribers.sqlite` for the waitlist — **not** committed; see `landing/README.md`.

Future additions, when they're justified by actual work — not before:

```
├── web/                  Web dashboard (Phase 2; React/Next.js most likely)
├── shared/               Cross-language schemas (e.g. sync API payloads for Phase 2)
├── infra/                IaC (Terraform / Pulumi) once we have anything to deploy
└── tools/                One-off scripts, codegen, CI helpers
```

Rules of the road:
- **No code at the repo root.** Anything code-like lives under exactly one top-level folder.
- **Each top-level folder owns its own toolchain.** `app/` has `pubspec.yaml`; a future `services/api/` has its own `package.json` or `pyproject.toml`. We do not invent a global build system on day one.
- **Cross-cutting contracts live in `shared/`** when they exist (e.g. sync/API schemas for Phase 2). Until then, the contract is documented in `docs/`.
- **The root README is a map**, not a tutorial. It points at each folder's own README.

### 11.2 The mobile app — `app/`

Standard Flutter project shape, with the source organized feature-first:

```
app/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── lib/
│   ├── main.dart
│   ├── app/             (theme, go_router, shell, Riverpod providers)
│   ├── core/            (ids, format, clock)
│   ├── data/
│   │   ├── db/          (sqflite schema v1 + default tag seed)
│   │   ├── repositories/(JobsRepository, ItemsRepository, TagsRepository)
│   │   └── storage/     (MediaStorage — media/<job_id>/<item_id>/)
│   ├── domain/
│   │   ├── models/      (Job, Item, Tag, MediaFile, TimelineItem, …)
│   │   └── services/    (ExportService — zip + index.html + media folders)
│   └── features/
│       ├── jobs/        (list, form, detail)
│       ├── capture/     (hub, photo, voice, note, tag_chips widget)
│       ├── item_detail/
│       ├── export/
│       └── settings/
├── test/                (placeholder today — see §11.3)
├── android/
└── ios/
```

- Repositories are the only thing feature screens talk to; they own SQLite + filesystem.
- Riverpod providers (`app/providers.dart`) expose async lists and invalidate on a simple data-revision counter.
- `ExportService` is pure Dart aside from file IO — intended for unit tests once added.
- No `integration_test/` or `lib/l10n/` directory yet.

### 11.3 Testing

**Target:**

- **Unit:** repositories, services, model mapping, zip / `index.html` builder.
- **Widget:** every screen with golden tests for the main states (empty, loaded, error).
- **Integration:** capture → save → appears in timeline → export → share sheet.

**Current:** `app/test/widget_test.dart` is a placeholder (`1 + 1`). Run `flutter test` from `app/` before expanding coverage. Priority next: `ExportService`, repository mapping, then golden tests for Jobs list and Export screen.

### 11.4 Backend services — `services/` (placeholder for now)

`services/` exists through **Phase 1** only as an empty scaffold with a README explaining its future contents. **Nothing is built here during Phase 1** — the mobile app does not depend on our backend for local use (§8.2). When Phase 2 is greenlit ([§14.5](#145-decision-gate)), the MVP layout is intentionally **two** services:

```
services/
├── api/                 Go — auth, CRUD, sync, signed URLs, Paddle webhooks, outbound email
└── pdf/                 Rust — HTML → PDF worker (Postgres queue consumer)

(future, when justified)
└── transcribe/          Speech-to-text worker → cloud transcript rows (post-MVP)
```

No separate `auth/`, `sync/`, or `webhooks/` services in MVP — those collapse into `services/api/` and only split when load or team size justifies it. Each service is its own deployable unit with its own README, dependencies, and CI lane. They share contracts via `shared/` (OpenAPI generated from the Go API) when introduced.

### 11.5 Why monorepo (and not multi-repo)

- One source of truth for cross-cutting API contracts (sync payloads shared by `app/`, `services/sync/`, and `services/pdf/` — they must not drift).
- One PR can touch both sides of a feature when a future change crosses the mobile/backend boundary.
- Cheaper at our scale — one repo, one issue tracker, one CI config evolving over time. We can split if/when it actually hurts.

---

## 12. Future-Proofing for Phase 2 (Paid Tier)

The **Phase 1** app must not paint us into a corner for **Phase 2** ([§17](#17-phase-2-dashboard-sync-subscription-and-teams)). Concretely:

- **Stable IDs:** all entities use UUIDs generated on-device, never auto-increment ints, so future sync can merge across devices.
- **Timestamps everywhere:** `created_at` and `updated_at` on every row → trivial last-writer-wins or CRDT layer later.
- **Soft delete (optional, behind a flag):** hard delete in Phase 1 today; reserve `deleted_at` via a future migration when sync ships (column not in schema v1 yet).
- **Repository abstraction:** swapping the SQLite-only repo for a "SQLite + remote" repo is a one-layer change.
- **Settings has a dormant "Account / Subscription" entry** that is hidden in Phase 1 and flipped on when Phase 2 ships.
- **Export format is documented and stable**, so the future web app can ingest old exports.

What Phase 2 adds (out of scope for **Phase 1**, but mapped here and detailed in [§17](#17-phase-2-dashboard-sync-subscription-and-teams)):
- Auth (**email + password**, **email magic link**, **Google OAuth** implemented; **Sign in with Apple** planned; password reset via SMTP; JWT + rotating refresh token) + **team subscription** billing via **Paddle** (web checkout; App Store / Play in-app billing deferred). Detail: [§17.9](#179-authentication-sign-in-methods), [`web-dashboard-design.md` §10, §11](web-dashboard-design.md#10-billing-paddle--plan-sku-naming).
- Sync engine (most likely Supabase or a small custom service over Postgres + object storage).
- Web dashboard (same logical model as the app; PDFs and reporting live here).
- Voice-note transcription on the **web dashboard** (server-side, batch; cloud storage only — see [§17.7](#177-voice-transcription-as-readable-notes-phase-2)).
- Branded PDF (logo, colors, header/footer, custom templates).
- **Team workspaces** — shared jobs and notes across members on one plan.

---

## 13. Phasing / Milestones

| Milestone | Scope | Status (May 2026) |
| --- | --- | --- |
| **M0 — Skeleton** | Flutter project, theming, routing, SQLite v1 + default tags | **Done** |
| **M1 — Jobs CRUD** | Create/edit/delete, list, search, status | **Done** |
| **M2 — Capture loop** | Camera, photo/voice/note/**PDF upload**, captions, tags (**`Receipt`**), timeline, item detail | **Mostly done** — gaps: photo+voice combo UI, timeline thumbs, “Today” UX |
| **M3 — Export** | Selection, options, zip (`index.html` + media), share sheet | **Done** |
| **M4 — Polish & ship** | Settings completeness, permissions UX, a11y, tests, store assets, beta | **In progress** |

Original timeboxes (for planning): M0 ~1w, M1 ~1w, M2 ~2w, M3 ~1w, M4 ~1–2w (~5–7 weeks total to public Phase 1).

**After M4 (start Phase 2 — completes the MVP)**  
Backend, auth, billing, sync service, web dashboard, and team UX ship only after [§14.5](#145-decision-gate). See [§17](#17-phase-2-dashboard-sync-subscription-and-teams).

---

## 14. Distribution & Market Validation

**Phase 1** exists primarily to answer: **will small contractors actually open a lightweight field-record app during the job** instead of using camera roll, texts, paper, and memory? Secondary signal: **is there demand for Phase 2** (paid team subscription: sync, dashboard, shared jobs)? Build effort on sync, transcription, branded PDFs, and the web dashboard is only justified if the free app finds an audience first.

The validation question is no longer only “Do contractors need photo documentation?” — it is whether our capture loop is **fast enough to replace** habitual camera-roll and text-message workflows ([§3.6](#36-mvp-feature-priorities)).

### 14.1 What "traction" means here

We're not chasing DAU — that's the wrong yardstick for a tool a contractor opens *on* a job, not between jobs. The signals that actually matter:

| Signal | Why it matters | Target (rough, first 3 months) |
|---|---|---|
| Installs | Reach — does the pitch land? | 1,000+ |
| Day-7 retention | Did they come back for a second job? | ≥ 25% |
| Jobs created per install (P50) | Real usage, not just "tried it" | ≥ 2 |
| Exports per install (P50) | Got value out the other end | ≥ 1 |
| Store rating | Quality bar / word-of-mouth fuel | ≥ 4.4 |
| **Waitlist signups for Pro** | Direct demand signal for Phase 2 | **≥ 10% of installs** |
| Inbound feedback emails | Qualitative — what they actually want next | any, treat each as gold |

The waitlist conversion is the headline number. If 100 contractors install the free app and 15 of them voluntarily hand over an email saying "tell me when sync/PDF/web ships," that's a credible buy signal. If they install and never tap that row, the Phase 2 pitch is a different product than we thought.

### 14.2 How we measure (without collecting job content)

For **local-only** users, we do not need job photos or timelines on our servers to learn whether the product works. Measurement stays proportionate:

What we **do** use:
- **App Store / Play Console metrics** — installs, retention aggregates, ratings, crash-free %, search terms. Normal for any app; no access to job content.
- **Voluntary waitlist** — Settings links to the site; the user submits email and optional fields if they want updates on Phase 2. Stored in our waitlist DB, separate from the app.
- **Voluntary feedback** — `mailto:` when the user chooses.
- **Public store reviews.**

What we **do not** put in the **Phase 1 app**:
- No in-app analytics SDK (Firebase Analytics, Mixpanel, Amplitude, PostHog, etc.).
- No third-party crash reporter enabled by default (see Open Questions if we add opt-in reporting later).
- No mandatory onboarding profile fields.

Marketing can say **local-first** and **no account required for capture** — not absolutes like "we never see your data" (waitlist and store metrics are the obvious exceptions). The product story is: job content stays on the phone until the user exports it or, in Phase 2, opts into sync.

### 14.3 Distribution plan

Phased rollout, cheapest channels first:

1. **Closed alpha (TestFlight + Play Internal)** — ~10 hand-picked contractors, recruited through personal network / r/Contractor / r/Construction / local trade FB groups. Goal: catch the obvious bugs, validate the capture loop is **faster than camera roll + texts** on real job sites.
2. **Open beta (TestFlight public link + Play Open Testing)** — a one-page landing site with the pitch, the four mockup hero shots, and "Join the beta" buttons. Push to the same communities. Goal: 100–200 beta users, dial in onboarding and permissions UX.
3. **Public launch** — App Store + Play Store. Coordinate a launch post on:
   - r/Contractor, r/Construction, r/HomeImprovement, r/Plumbing, r/Electricians, r/HandymanProfessional (read the rules of each first — most ban promotional posts, so this is "I built a free tool, would love feedback" not "I'm selling something").
   - Trade-specific Facebook groups (these are where the actual audience lives).
   - One short Show HN / IndieHackers post — secondary audience, but useful for the "tech-aware contractor" niche.
   - Twitter/X + LinkedIn for indie-maker visibility (low-yield for end users but high-yield for press / future investors).
4. **Earned coverage (cheap)** — pitch one trade publication (e.g. *Pro Tool Reviews*, *Tools of the Trade*, *Contractor Talk*) once we have a working app and a few testimonials.

We do **not** do paid acquisition during the market test. Paid traffic distorts the signal — we want to know if the product spreads on its own merits before spending a cent.

### 14.4 The landing site

**Implemented** in `landing/` — deployed at **jobsiterecords.com** (PHP 8+ on Apache; see `landing/README.md`). Still **no analytics pixels** and **no marketing-automation hooks** by design.

**Core pages**

| Piece | Role |
| --- | --- |
| `index.php` | Home + early-access waitlist form (name, company, role, pain point, optional call consent) |
| `export.php` | Password-protected CSV export of subscribers (`JOBSITERECORDS_EXPORT_PASSWORD`) |
| `lib/db.php` | SQLite PDO; DB path `../private/subscribers.sqlite` when writable, else `landing/.data/` |
| `sitemap.php` / `sitemap.xml` | SEO sitemap (static file regenerated on deploy or via `generate-sitemap.php`) |

**SEO content hubs** (many PHP pages, shared layout in `lib/seo-layout.php`):

- `guides/` — how-tos (export zip, tags, voice notes, offline use, change orders, …)
- `use-cases/` — scenario pages (remodel progress, water damage, closeout, …)
- `trades/` — trade-specific documentation pages
- `answers/` — comparison / FAQ-style articles
- `examples/` — sample captions, checklists, email templates

The home page still does the two jobs from the original one-pager plan: (a) convert visitors into installs / beta interest and (b) capture waitlist emails. Settings → **What's next** opens the same site (`https://jobsiterecords.com/`). **One waitlist, two entry points.**

Messaging on the home page aligns with [§3.4](#34-positioning--messaging): **job notes, photos, and files organized by project** — free offline field record, not a CRM or estimating tool. Phase 2 cloud/dashboard/PDF called out as coming soon for teams who want it. App Store / Play badges appear when builds are ready for public listing.

### 14.5 Decision gate

We re-evaluate funding **Phase 2** after **3 months post–Phase 1 launch** with the metrics in §14.1 in front of us. Three outcomes:

- **Strong signal** (waitlist ≥ 10% of installs, retention ≥ 25%): build Phase 2 as scoped in [§17](#17-phase-2-dashboard-sync-subscription-and-teams) — sync, web dashboard, PDF reports, transcription, team workspaces. Probably ~6 months of work.
- **Mixed signal** (good installs, weak waitlist, OR weak installs but strong feedback): the product is interesting but the paid pitch is wrong. Re-interview the waitlisters and the top engaged users before building anything more.
- **Weak signal** (low installs, low retention, no waitlist): keep the free app running as a portfolio piece, do not invest in Phase 2. Cheap to maintain because there's no backend.

---

## 15. Open Questions

1. **Brand & domain** — **Decided:** **Job Site Records** at **jobsiterecords.com**. Alternate "BUILT Field Notes" mark remains mockup-only unless we revisit branding.
2. ~~**Visual direction**~~ — **Decided:** light + amber accent for Phase 1 ([§10](#10-visual-design)).
3. ~~**File import in Phase 1**~~ — **Decided:** **PDF / file upload** ships in Phase 1 as a must-have ([§6.6a](#66a-capture-file--pdf-upload)). PDF is the v1 priority; other formats follow the same path. Target: complete before M4 ship unless blocked by picker/platform issues.
4. ~~**Default tag expansion**~~ — **Decided (partial):** **`Receipt`** ships as a Phase 1 must-have default tag ([§7](#7-data-model)), paired with PDF/file upload. Stretch tags (`Follow-up`, `Material`, `Change Order`, `Client Request`) ship in the same migration if low effort; otherwise immediately after. Migration inserts by name for existing installs.
5. **Biometric lock on app open** — Phase 1 or Phase 2?
6. **Photo storage policy** — keep originals forever, or offer a "compress originals" toggle in settings to manage device storage?
7. **Single-photo vs. multi-photo item** — current model is one primary photo per item; do we want a "burst" / album-style item from day one?
8. **Edit history** — do we keep prior versions of captions/tags, or is overwrite fine for Phase 1? (Overwrite is fine for Phase 1; revisit with sync.)
9. **Crash reporting** — none in Phase 1, or local-only logs the user can email if something breaks?
10. ~~**Note editor UX**~~ — **Decided:** users edit in a **WYSIWYG editor** only; markdown is internal serialization, never shown ([§6.6](#66-capture-text-note)). Open sub-question: which Flutter rich-text package and whether v1 stores markdown or Quill Delta in `items.body` (markdown preferred for export/sync simplicity).
11. **Annotation tool palette** — does the v1 set (pen, line, arrow, circle, rectangle + 5 colors) cover the common asks, or do we need **blur / redact** for client privacy before public launch? ([§6.4a](#64a-photo-annotation-mark-up))
12. **Annotated photos in zip exports** — always include the **original** alongside the flattened render (current plan), or make “include originals” an export toggle to keep zips small?

---

## 16. Out of Scope (explicit)

**Fence, not a backlog:** features below stay out unless we consciously open a new phase and accept the cost. Default answer remains **no**.

To keep **Phase 1** shippable on its own, the following are **explicitly not in scope**:
PDF generation, **PDF annotation**, **full word-processor note editing** (tables, embedded images, links, fonts/colors — the **basic WYSIWYG subset in [§6.6](#66-capture-text-note) is in scope**), **image filters / cropping / measurement tools beyond the annotation set in [§6.4a](#64a-photo-annotation-mark-up)**, accounts, login, cloud, sync, web app, team sharing, comments, push notifications, in-app purchases, transcription, AI summaries, custom report templates, logos/branding, multi-language UI, tablet-optimized layouts, Apple Watch / Wear OS companions.

Most of the above list becomes **in scope in Phase 2** under a paid team subscription; see [§17](#17-phase-2-dashboard-sync-subscription-and-teams). Phase 1 remains a free, local-only app path indefinitely.

---

## 17. Phase 2: Dashboard, sync, subscription, and teams

This section defines the **second delivery phase** of the **MVP** — dashboard, sync, subscription, and teams — and completes the scope in [§2](#2-goals--non-goals). **Phase 1** is the shipped mobile app ([§13](#13-phasing--milestones)). Nothing in this section is committed work until the **decision gate** in [§14.5](#145-decision-gate) says go.

**Dashboard detail:** screens, flows, sync protocol, slices, and **user-testable milestones (M0–M8)** are expanded in [`web-dashboard-design.md`](web-dashboard-design.md). Phase 2 ships in eight reviewable milestones — clickable shell → auth → web CRUD → mobile text sync → media sync → teams → hardening → PDF reports → billing — see [`web-dashboard-design.md` §17](web-dashboard-design.md#17-milestones-user-testable-states).

### 17.1 Product promise by phase

| | Phase 1 (mobile app, first delivery) | Phase 2 (dashboard, sync & teams — completes MVP) |
|---|---|---|
| **Price** | Free | **Subscription** for workspace features (see below) |
| **Account** | None | Required **only** when enabling sync / dashboard / team |
| **Data default** | On-device only | Same local-first UX; cloud is **opt-in** per user or per workspace |
| **Multi-user** | Single device user | **Team workspace:** many users, shared jobs and content |

**Core commercial rule:** installing and using the app **without** subscribing **stays free forever** for full local capture, organization, and zip export. We do not paywall the field workflow that Phase 1 already delivers. Subscription unlocks **sync**, the **browser dashboard**, **shared team access**, and the Pro-only generators (PDF, transcription, etc.)—not basic recording on the phone.

### 17.2 What the subscription buys (billing unit: team / workspace)

Billing is anchored to a **workspace** (synonyms: team, company account) — one subscription covers the crew, not each phone individually. Launch SKUs are `solo_1`, `crew_5`, `team_15` (owner counts toward the seat limit); price points live in **Paddle** ([`web-dashboard-design.md` §10](web-dashboard-design.md#10-billing-paddle--plan-sku-naming)). The design intent:

1. **Cloud sync** — jobs, items, media metadata, and blobs sync across **members' devices** that join the workspace. Conflict handling builds on Phase 1 IDs and timestamps ([§7](#7-data-model), [§12](#12-future-proofing-for-phase-2-paid-tier)).
2. **Web dashboard** — sign in on the web to browse the same jobs, filter exports, manage **branded PDF reports**, and (later) org-wide settings. Heavier than the phone by necessity, but still **narrow**: jobs, exports, reports — not a generic PM product.
3. **Team access** — every invited **member** sees the **workspace's jobs** (subject to role). "Share access to notes" means shared **Job** and **Item** timelines and text notes—not a separate siloed note product: the collaboration surface is the same entities as the app today, backed by sync.
4. **Pro pipeline features** — voice **transcription** (recordings → readable text notes; see [§17.7](#177-voice-transcription-as-readable-notes-phase-2)), **AI summaries**, advanced templates, audit-friendly exports — only where they clearly support evidence + handoff; no feature sprawl.

Users who never create a workspace and never sign in **never pay** and **do not upload job content to our servers** (local-only use only).

### 17.3 Team model (multiple users, one subscription)

- **Workspace** — the billable root. Has a name, billing owner, subscription status, and retention policies.
- **Members** — human users identified by email. One user can belong to many workspaces; the mobile **context switcher** (`Local` + every workspace) is always available ([`web-dashboard-design.md` §20](web-dashboard-design.md#20-mobile-app-changes-required-phase-2)).
- **Roles** — **Owner** and **Member** only in MVP. Owner manages billing, team, and workspace settings; member captures and edits on **assigned** jobs (decision D2 in the dashboard spec). Admin / Viewer / Client roles are explicitly out of MVP scope.
- **Invites** — owner invites by email; invitee installs the free app (or uses web), signs in (Google, Apple, email + password, or magic link), and joins the workspace. Invite emails may include a magic link for one-tap accept. Mobile sync for members is **per-assignment**; owners sync everything in the workspace.
- **Personal vs. workspace jobs** — resolved: the phone always has a **Local** context (unsynced, on-device only) plus any team workspaces the user belongs to. **Move local job to workspace** is a one-way promotion endpoint ([`web-dashboard-design.md` §15.6](web-dashboard-design.md#15-sync-api--protocol)). Cross-workspace moves are post-MVP.

### 17.4 Technical sketch (high level)

- **Auth** — **email + password**, **email magic link**, and **Google OAuth** are **implemented**; **Sign in with Apple** is planned ([§17.9](#179-authentication-sign-in-methods)). **JWT access token (15 min) + rotating opaque refresh token (30 d)**; per-session row in DB. Session and API detail: [`web-dashboard-design.md` §11](web-dashboard-design.md#11-auth--sessions).
- **Outbound email** — transactional SMTP from the Go API (password reset, magic links, invites). Config in repo root `.env` (local) and `.env.deploy` (production) — [§17.9](#179-authentication-sign-in-methods).
- **Billing** — **Paddle** as Merchant of Record (Iceland-friendly, no Stripe dependency). Hosted Customer Portal; webhooks handled inline in the Go API; lapse triggers a 14-day read-only grace period. App Store / Play in-app billing is **deferred**; RevenueCat is **not** in MVP.
- **API + sync** — single **Go** service (`services/api/`) hosts auth, CRUD, sync, signed URLs, webhooks, and outbound email. REST/JSON with OpenAPI for client generation. Sync is **per-job** with last-writer-wins on `updated_at`, soft delete + 30-day tombstones, and direct-to-S3 blob uploads via signed URLs. Read-only edges when assignment, membership, or subscription lapses. Full protocol: [`web-dashboard-design.md` §15](web-dashboard-design.md#15-sync-api--protocol).
- **PDF rendering** — separate **Rust** worker (`services/pdf/`) polling a Postgres queue (`reports.status` + `SKIP LOCKED`); only async service in MVP.
- **Storage** — Postgres (relational + queue) + S3-compatible object store (MinIO in dev). No Redis in MVP.
- **Dashboard** — `web/` (Next.js + TypeScript) on `app.jobsiterecords.com`; shares types via `shared/` (OpenAPI) when introduced.
- **Privacy (sync users)** — encryption in transit and at rest; workspace isolation; clear **export and deletion** for workspace data. Messaging: **local-first by default**; cloud sync is **opt-in** and covered in the privacy policy.

### 17.5 Relationship to Phase 1 code and repo

Phase 2 **extends** the monorepo: `services/api/` (Go), `services/pdf/` (Rust), `web/` (Next.js), and app changes for sign-in and sync live alongside Phase 1. The Flutter app gains **optional** network modules and adds local sync-state columns (`sync_state`, `last_sync_attempt_at`, `remote_etag?`) without removing anything from Phase 1; repositories become "local + remote" behind the same interfaces ([§12](#12-future-proofing-for-phase-2-paid-tier)). Phase 1 builds and tests remain **fully offline** in CI so the free path never regresses.

### 17.6 Explicitly still out of scope for Phase 2 v1 (examples)

To avoid scope creep in the **first** cloud release: real-time co-editing presence, comments threads on items, arbitrary external sharing links with ACLs, enterprise SSO, multi-region data residency, and **receipt OCR / expense spreadsheet export** can wait until **Phase 2+** unless a customer pulls us there.

### 17.7 Voice transcription as readable notes

- **Goal:** on the **web dashboard**, teammates can **read** what was said on a job without scrubbing through every clip. Transcription is a **paid / cloud** feature — not native STT in the Flutter app.
- **Phase 1 (*implemented*):** voice notes are **audio only** (plus caption/tags). No transcript column in local SQLite, no transcript UI, no platform speech APIs in the app. Users who want readable spoken text on the phone add a **text note** (OS keyboard dictation is fine).
- **Phase 2 (paid / cloud):** optional **“Transcribe”** (or auto-transcribe on upload) in the **dashboard**, backed by `services/transcribe/`. Transcript text is stored in the **server** data model (e.g. a `voice_transcripts` or workspace-scoped annotation table keyed by synced `item_id`) — **not** by adding `items.transcript` to the Phase 1 mobile schema. Search, edit, and PDF blocks use that cloud copy. The mobile app may **display** synced transcript later if we choose, but it does not own transcription or reserve a local column for it. The **audio file remains the source of truth**; transcript is derived data the user may **fix** on the dashboard (trade terms, names, mumbling).

### 17.8 Receipt OCR & job expenses (post-MVP dashboard)

- **Goal:** on the **web dashboard**, turn **`Receipt`-tagged** timeline items into a **reviewable expense roll-up** for a job — vendor, date, totals — without retyping paper slips. Export **CSV / Excel** for bookkeeping handoff. **Not** invoicing, estimating, or a full accounting integration ([§17.6](#176-explicitly-still-out-of-scope-for-phase-2-v1-examples)).
- **Phase 1 (*target*):** contractors tag receipts on the phone ([§6.6a](#66a-capture-file--pdf-upload), [§7](#7-data-model)); timeline filter + zip export carry those items to the office manually.
- **Post-MVP (paid / cloud):** after sync, a server worker OCRs receipt photos/PDFs; structured fields stored server-side (e.g. `receipt_extractions` keyed by synced `item_id`) — **not** new columns in the Phase 1 mobile schema. Dashboard **Expenses** view on job detail; user may correct extracted values; export spreadsheet. Detail: [`web-dashboard-design.md` §8.2](web-dashboard-design.md#82-receipt-ocr--job-expenses).

### 17.9 Authentication (sign-in methods)

Phase 2 sign-in is **optional** — required only when the user enables cloud sync, the web dashboard, or a team workspace ([§17.1](#171-product-promise-by-phase)). The free local capture path never requires an account.

**Implemented today:** **email + password** (sign-up, login, password reset), **email magic link**, and **Google OAuth** (web redirect + mobile ID token → `POST /api/v1/auth/oauth/google`). Password and magic-link paths **remain supported**; Google links to an existing account when the verified email matches.

**Planned:** **Sign in with Apple** ([`web-dashboard-design.md` §11](web-dashboard-design.md#11-auth--sessions)). Google is hidden on **iOS** in the Flutter app until Apple ships (App Store third-party sign-in rule).

| Method | Status | Flow | Best for |
| --- | --- | --- | --- |
| **Email + password** | **Implemented** | Enter email and password → API verifies → session issued | Default today; familiar login; office staff on a shared tablet |
| **Google** | **Implemented** (web + Android; iOS after Apple) | Tap **Continue with Google** → OAuth / ID token → API verifies → session issued | Users already signed into Google on the device |
| **Apple** | Planned | Tap **Sign in with Apple** → Apple ID consent → session issued | iOS users; **required by App Store** when other third-party sign-in is offered |
| **Email magic link** | **Implemented** | Enter email → receive single-use link → tap link → session issued | Passwordless email sign-in |

All four methods are **MVP** on **mobile and web** once complete. Team invites and workspace-join emails may use magic links so invitees land signed in with one tap.

**Account linking (when OAuth ships):** one `users` row per person. When Google or Apple returns a verified email that already exists (e.g. from email + password or magic-link sign-up), link the OAuth provider to that account instead of creating a duplicate. Apple's private relay addresses are treated as first-class emails for that user.

#### Password reset (email + password — implemented)

Users with a password account can recover access without support:

1. **Forgot password** — user enters email on web or mobile → `POST /api/v1/auth/forgot-password`.
2. **Email** — API sends a single-use link to that address (same response whether or not the email is registered — no account enumeration).
3. **Reset** — link opens `{APP_URL}/reset-password?token=…` (web) or app deep link; user sets a new password → `POST /api/v1/auth/reset-password`.
4. **TTL** — reset token expires in **30 minutes**; one use only. Stored hashed in `auth_one_time_tokens` (`kind = password_reset`).

Magic-link sign-in and OAuth do not use this flow; password reset applies only to accounts with (or adding) a password.

#### Outbound email (SMTP)

The Go API sends transactional email inline (password reset today; magic links and team invites when those ship). **SMTP** is configured via environment variables in:

- **Local dev:** repo root `.env` (read by `docker-compose.yml` for the `api` service)
- **Production:** `.env.deploy` (read by `docker-compose.deploy.yml`)

| Variable | Example / default | Purpose |
| --- | --- | --- |
| `SMTP_HOST` | `mail.1984.is` | SMTP server hostname |
| `SMTP_PORT` | `587` | SMTP port (STARTTLS on 587) |
| `SMTP_USERNAME` | *(set in env)* | SMTP auth username |
| `SMTP_PASSWORD` | *(set in env)* | SMTP auth password |
| `SMTP_FROM_EMAIL` | *(set in env)* | Envelope / From address (e.g. `noreply@jobsiterecords.com`) |
| `SMTP_FROM_NAME` | `Job Site Records` | Display name on outbound mail |

When SMTP is not configured (empty username/password), local dev may log the reset link to the API container stdout instead of sending mail — useful for testing without a mailbox. Production **must** set all SMTP variables in `.env.deploy`.

**Sessions (all methods):**

- **JWT access token (15 min)** + **opaque rotating refresh token (30 d)**; one row per device/session in `auth_refresh_tokens`.
- Mobile sends `Authorization: Bearer …`; web uses HTTP-only cookies via the Next.js BFF.
- Same session shape regardless of how the user signed in — sign out, refresh, and “active devices” behave identically.

**Platform notes:**

- **Email + password (today):** `POST /api/v1/auth/signup`, `POST /api/v1/auth/login`; Argon2id password hashing (min 10 chars; breached-password list rejection). See [`web-dashboard-design.md` §11](web-dashboard-design.md#11-auth--sessions).
- **Google (implemented):** `POST /api/v1/auth/oauth/google` with ID token from web BFF or mobile `google_sign_in`. Env: `GOOGLE_CLIENT_ID` (comma-separated allowed `aud` values).
- **Apple (planned):** `POST /auth/oauth/apple` with identity token; private relay emails supported.
- **Magic link (planned):** `POST /auth/magic-link` + verify URL; 15 min TTL; mobile deep-link handler.

**Explicitly not in MVP:** enterprise SSO (SAML/OIDC beyond Google/Apple consumer flows), SMS OTP.

Endpoint-level detail, rate limits, and DB columns: [`web-dashboard-design.md` §11](web-dashboard-design.md#11-auth--sessions).
