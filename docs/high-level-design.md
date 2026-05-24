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
| Flutter app (`app/`) | **Mostly built** | v0.1.0+1; jobs CRUD, **Google Places address autocomplete** on New/Edit Job (online; worldwide search; API key in `app/.env`), **batch-first photo capture**, voice/note capture, timeline **filter/search** (type, tag, full-text), bulk tag, item detail, zip export, settings. Voice notes are audio + optional caption/tags; for spoken text users add a **text note** (keyboard dictation on Android/iOS). Automatic transcription is **Phase 2** (server). Gaps: file import, expanded default tags ([§6.10](#610-implementation-gaps-vs-target-phase-1)). |
| Landing (`landing/`) | **Active** | PHP + SQLite waitlist on jobsiterecords.com, plus SEO guides, use cases, trades, answers, and examples — not a single static page ([§14.4](#144-the-landing-site)). |
| Backend (`services/`) | **Placeholder** | README only; no deployable services yet. |
| Web dashboard (`web/`) | **Not started** | Phase 2. |
| Tests | **Minimal** | Placeholder unit test only; golden/integration tests not yet written ([§11.3](#113-testing)). |
| i18n / dark theme | **Not started** | English strings inline; light theme only ([§4](#4-platform--tech-stack), [§10](#10-visual-design)). |

**Milestone progress ([§13](#13-phasing--milestones)):** M0–M3 largely complete in code; M4 (polish, accessibility, golden tests, store assets) still in progress.

---

## 1. Product Overview

Contractors are not lacking ways to take photos or notes. They are lacking a **simple job-centered record system**. Today that information is scattered across camera roll, Google Photos, cloud folders, texts, paper notes, spreadsheets, invoice tools, CRM/PM tools, and memory.

Job Site Records is **not** a photo app. It is a **lightweight, offline job timeline** for photos, voice notes, text notes, files, tags, and exports — organized by job.

The product centers on a **mobile app** that helps contractors capture and retrieve field records without paperwork or cloud setup; the **MVP** also includes the **Phase 2** **web dashboard** and **cloud sync** for teams who subscribe ([§2](#2-goals--non-goals)). Users create a job folder, capture photos/voice/text/files, add captions and tags, browse a chronological timeline, and export a tidy zip archive when they need a clean handoff.

The core loop stays **shallow**: open app → pick job → tap photo / note / voice / file → save → done. Optional cloud (Phase 2) must not crowd that path for local-only users.

**Phase 1** (first ship) is the **mobile app alone**: **free, local-first, no account**. Job content is stored on the device and is not synced to our servers. Sharing is through the OS share sheet (email, SMS, AirDrop, WhatsApp, Drive, etc.) when the user chooses. Phase 1 does **not** include PDF generation — that ships with the **Phase 2** web dashboard.

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

- **No PDF generation in the app.** PDF reports ship with the Phase 2 web dashboard.
- No cloud sync, no accounts, no multi-device (in Phase 1).
- No team collaboration / sharing inside the app (in Phase 1).
- No **cloud** AI (server transcription, summarization) in Phase 1. **Automatic** on-device voice-to-text is also **out of scope for Phase 1** — Android's system `SpeechRecognizer` holds the mic exclusively (it can't run alongside `MediaRecorder`), file-based recognition is unreliable across OEMs, and playback-into-mic workarounds make the device beep / dim media volume in ways field users will not tolerate. Users who want spoken words as text add a **text note** (OS keyboard dictation) alongside or instead of a voice clip.
- No web app in Phase 1.
- No in-app analytics SDKs or third-party tracking in the Phase 1 app (see [§8.2](#82-privacy--security) for what we do and don't collect).

### Phase 2 goals (dashboard, sync, and paid tier — second delivery; completes MVP)

Phase 2 is **out of scope for the Phase 1 milestone**; it is the next delivery phase once the decision gate in [§14.5](#145-decision-gate) is met. Headline capabilities:

- **Scope discipline:** ship **sync, dashboard, teams, PDF, transcription** — not a general contractor platform. Default answer to new ideas is **no** unless they serve that core; defer rest to [§17.6](#176-explicitly-still-out-of-scope-for-phase-2-v1-examples) / later.
- **Paid subscription** unlocks **cloud sync**, the **web dashboard**, and **team workspaces** (multiple users on one subscription share access to jobs, timeline items, and notes). The **mobile app stays free** for local-only use ([§17](#17-phase-2-dashboard-sync-subscription-and-teams) for full definition).
- Optional sign-in (only when the user or org opts into Pro).
- Encrypted cloud backup + multi-device sync for subscribed workspaces.
- **Web dashboard** with the same data as synced devices — this is where **PDF report generation** lives (branded, with logo / header / footer / templates).
- Voice-note **transcription**: sound recordings are turned into **text notes** (auto-generated, editable) so timelines, item detail, and reports are **easy to read and search** without playing every clip; AI summaries per job / per day (server-side, queued).
- **Team model:** one **workspace** (company / crew) billed as a unit; **members** invited by email; **roles** (e.g. owner, admin, member, read-only) gate who can edit jobs vs. view-only.

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
- Add caption
- Add tags
- Timeline grouped by date
- Search jobs
- Export zip with photos, notes, timestamps, tags, and `index.html`

**Strongly consider for MVP (Phase 1 stretch)**

- Import file / attachment (PDF, receipt, permit, etc.)
- Attach file to job timeline with caption + tags
- Tag files and notes with business-oriented categories
- **“Today”** section or pin at top of job timeline (same date grouping, faster scan)
- Default tag set includes: Issue, Follow-up, Material, Change Order, Client Request, Receipt (see [§7](#7-data-model))

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
- **Local storage:** `sqflite` for metadata (schema version **1** — `items` has no transcript column); `path_provider` documents directory for media.
- **Camera:** `camera` for live capture; `image_picker` for gallery import on the photo review flow.
- **Audio:** `record` (v5.1.2) for capture, `just_audio` for playback. No dedicated waveform package yet — voice UI uses elapsed time + play/pause slider.
- **Voice transcription:** **not on the phone.** Voice items are audio + caption/tags only. Phase 2 adds optional **dashboard/cloud** STT after sync — no native hooks and no `transcript` column in the local `items` table ([§17.7](#177-voice-transcription-as-readable-notes-phase-2)).
- **Zip export:** `archive` (pure Dart).
- **Sharing / links:** `share_plus` for exports and single-item share; `url_launcher` for waitlist, feedback `mailto:`, and privacy policy URLs in Settings.
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
2. **Capture** — quick-capture entry. **Implemented:** lists jobs, then a bottom sheet to pick Photo / Voice / Text for the chosen job (does not open the camera until a job is selected). **Target:** optional direct camera when a “current job” context exists; add **File** import to the mode sheet ([§6.6a](#66a-capture-file-import--strongly-consider-for-mvp)).
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
     │   └─ File mode (document picker — PDF, image, etc.)
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
- **Address (*implemented*):** when online and `GOOGLE_MAPS` is set in `app/.env`, the address field uses the native **Google Places SDK** (New API) for street-level autocomplete (worldwide; no country lock). Requires **Places API (New)** + **Maps SDK for Android** enabled on the key. Manual entry still works without picking a suggestion.
- "Create" returns to Job Detail.

### 6.3 Job Detail
- Header: back, job name, address, status pill, edit button, overflow menu.
- Summary chips: total items, photos, voice notes, notes, files, issues (counts).
- Tabs or sections: **Timeline** (default), **Notes**, **Details**.
- Timeline: grouped by date (newest first). When the job has captures **today**, show a **Today** section at the top (same rows as date grouping — not a separate data model). Each row = thumbnail/icon + time + caption preview + tag chips + overflow menu.
- **Timeline filter/search (*implemented*):** collapsed by default — app bar **search** icon expands the filter panel (search field, type chips, tag chips). When filters are active and collapsed, a **summary bar** shows the current filters (e.g. `“leak” · Photos · Issue`) with clear; tap the bar to expand again. Search matches caption, note body, and tag names (case-insensitive). Type chips filter by photo / voice / note (multi-select, OR). Tag filter: quick chips for tags used in the job (first six) plus **Tags** sheet for searchable multi-select when many tags exist; selected tags use OR semantics. Count chips stay at job totals; timeline header shows “N of M” when filters are active. Export and bulk select still operate on the full job.
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

### 6.5 Capture (Voice Note)
- Large centered waveform + elapsed time.
- Big record / pause / stop control. Cancel and save (check) actions.
- Optional caption field below.
- A voice note can be attached to a photo, or stand on its own.
- **Implemented (Phase 1):** record audio, optional caption and tags; item detail shows **player**, caption, and metadata. No transcript on device — use a **text note** for dictated/written text. Phase 2 transcription is **dashboard-only** ([§17.7](#177-voice-transcription-as-readable-notes-phase-2)).

### 6.6 Capture (Text Note)
- Plain multi-line note, optional caption, tags.

### 6.6a Capture (File import) — *strongly consider for MVP*
- System document picker (PDF, images, common office formats).
- Optional caption + tags before save.
- No advanced in-app preview/editing at first — filename + type icon on timeline is enough.
- Saved as `kind = file` on the job timeline; included in zip export under `files/`.
- Examples: estimate PDF, signed quote, receipt, permit, inspection report, change order, delivery ticket, client-provided photo, screenshot of email/text.

### 6.7 Item Detail
- Large media area (photo, audio player, file type icon + filename, or note body).
- For photos: pinch-zoom, swipe between items in the same job.
- For files: show name, mime type, size; open via OS “Open with…” when user taps (no built-in PDF viewer required in Phase 1).
- Below: timestamp, caption, tag chips, optional voice note player, free-text note.
- **Voice items (*implemented*):** audio player, caption, tags. Transcription deferred to Phase 2 **web dashboard** ([§17.7](#177-voice-transcription-as-readable-notes-phase-2)). Photos/notes/files unchanged.
- Actions: Share (single item), Add to Export, Edit, Delete.

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
| File import | Document picker → timeline item | **Not started** |
| Job detail | “Today” section when captures exist today | Date grouping only |
| Photo capture | Batch-first: rapid multi-shot, tag at end | **Implemented** — continuous camera, Done → shared caption/tags; per-photo timestamps |
| Photo capture | Inline “tap to record” voice on photo | Voice is a separate item kind (repo supports attaching voice to photo, UI does not expose it yet) |
| Photo capture | Zoom presets | Flash toggle + camera swap + gallery import |
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
  body?             (text note content)
  captured_at       (defaults to created_at; user can edit)
  created_at
  updated_at

MediaFile
  id (uuid, pk)
  item_id (fk Item)
  role              (primary_photo | voice_note | attachment | file)
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

**Progress / status:** `Before`, `During`, `After`, `Completed`

**Business / proof (support disputes, change orders, invoicing follow-up):** `Issue`, `Follow-up`, `Material`, `Change Order`, `Client Request`, `Receipt`

Each seeded tag gets a default **color** hex in `tags.color` (UI uses chip styling). User-extensible via Settings (add custom tags; default tags cannot be deleted). Trade tags like `Plumbing`, `Framing`, etc. are not bundled by default — users add their own.

### File layout on disk
```
<app documents>/
  jobsiterecords.db
  media/
    <job_id>/
      <item_id>/
        photo.jpg
        voice.m4a
        thumb.jpg
        attachment.pdf   (or original extension for imported files)
```

### Schema versioning
- **Current:** `AppDatabase` at schema **version 1**. The local `items` table does **not** include a `transcript` column (and never will for Phase 1).
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
- Storage — Android only, when needed for export.

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
 │   └─ 2026-05-13_09-15_before_kitchen-demo.jpg
 ├─ voice_notes/
 │   └─ 2026-05-13_10-42_water-damage.m4a
 ├─ notes/
 │   └─ 2026-05-13_10-42.txt
 └─ files/
     └─ 2026-05-13_14-30_change-order-signed.pdf
```

- `index.html` is a static, self-contained page with the job header, items grouped by date, captions, tags, `<audio>` tags for voice notes, and links/icons for attached files. No JS, no external assets. This is the human-friendly "report" view — good enough for **Phase 1**, and viewable on any device the user shares the zip to. No CSV or JSON sidecars — contractors hand off folders clients can open, not data files for spreadsheets or tooling.

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

`services/` exists through **Phase 1** only as an empty scaffold with a README explaining its future contents. **Nothing is built here during Phase 1** — the mobile app does not depend on our backend for local use (§8.2). When Phase 2 is greenlit ([§14.5](#145-decision-gate)), expect roughly:

```
services/
├── api/                 Public REST/GraphQL API for the web dashboard and synced clients
├── sync/                Sync engine (likely event-sourced; workspace/job replication API)
├── auth/                Auth + subscription / billing webhook handler (RevenueCat or direct)
├── transcribe/          Speech-to-text worker → cloud transcript rows (dashboard; not local `items` columns)
└── pdf/                 Server-side PDF report renderer (templates + branding)
```

Each service is its own deployable unit with its own README, dependencies, and CI lane. They share contracts via `shared/` (when it exists), not by reaching into each other's source.

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
- Auth + **team subscription** billing (store subscriptions, optional RevenueCat or direct Apple/Google + server webhook).
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
| **M2 — Capture loop** | Camera, photo/voice/note/file import, captions, tags, timeline, item detail | **Mostly done** — gaps: file import, photo+voice combo UI, timeline thumbs, “Today” UX, expanded default tags |
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
3. **File import in Phase 1** — strongly recommended by research ([§3.6](#36-mvp-feature-priorities)). Ship in M2 stretch or defer to M4 if capture-speed work slips?
4. **Default tag expansion** — add Follow-up, Material, Change Order, Client Request, Receipt to seed data (migration for existing installs)?
5. **Biometric lock on app open** — Phase 1 or Phase 2?
6. **Photo storage policy** — keep originals forever, or offer a "compress originals" toggle in settings to manage device storage?
7. **Single-photo vs. multi-photo item** — current model is one primary photo per item; do we want a "burst" / album-style item from day one?
8. **Edit history** — do we keep prior versions of captions/tags, or is overwrite fine for Phase 1? (Overwrite is fine for Phase 1; revisit with sync.)
9. **Crash reporting** — none in Phase 1, or local-only logs the user can email if something breaks?

---

## 16. Out of Scope (explicit)

**Fence, not a backlog:** features below stay out unless we consciously open a new phase and accept the cost. Default answer remains **no**.

To keep **Phase 1** shippable on its own, the following are **explicitly not in scope**:
PDF generation, accounts, login, cloud, sync, web app, team sharing, comments, push notifications, in-app purchases, transcription, AI summaries, custom report templates, logos/branding, multi-language UI, tablet-optimized layouts, Apple Watch / Wear OS companions.

Most of the above list becomes **in scope in Phase 2** under a paid team subscription; see [§17](#17-phase-2-dashboard-sync-subscription-and-teams). Phase 1 remains a free, local-only app path indefinitely.

---

## 17. Phase 2: Dashboard, sync, subscription, and teams

This section defines the **second delivery phase** of the **MVP** — dashboard, sync, subscription, and teams — and completes the scope in [§2](#2-goals--non-goals). **Phase 1** is the shipped mobile app ([§13](#13-phasing--milestones)). Nothing in this section is committed work until the **decision gate** in [§14.5](#145-decision-gate) says go.

### 17.1 Product promise by phase

| | Phase 1 (mobile app, first delivery) | Phase 2 (dashboard, sync & teams — completes MVP) |
|---|---|---|
| **Price** | Free | **Subscription** for workspace features (see below) |
| **Account** | None | Required **only** when enabling sync / dashboard / team |
| **Data default** | On-device only | Same local-first UX; cloud is **opt-in** per user or per workspace |
| **Multi-user** | Single device user | **Team workspace:** many users, shared jobs and content |

**Core commercial rule:** installing and using the app **without** subscribing **stays free forever** for full local capture, organization, and zip export. We do not paywall the field workflow that Phase 1 already delivers. Subscription unlocks **sync**, the **browser dashboard**, **shared team access**, and the Pro-only generators (PDF, transcription, etc.)—not basic recording on the phone.

### 17.2 What the subscription buys (billing unit: team / workspace)

Billing is anchored to a **workspace** (synonyms: team, company account)—one subscription covers the crew, not each phone individually. Exact seat limits and price points are TBD; the design intent is:

1. **Cloud sync** — jobs, items, media metadata, and blobs sync across **members' devices** that join the workspace. Conflict handling builds on Phase 1 IDs and timestamps ([§7](#7-data-model), [§12](#12-future-proofing-for-phase-2-paid-tier)).
2. **Web dashboard** — sign in on the web to browse the same jobs, filter exports, manage **branded PDF reports**, and (later) org-wide settings. Heavier than the phone by necessity, but still **narrow**: jobs, exports, reports — not a generic PM product.
3. **Team access** — every invited **member** sees the **workspace's jobs** (subject to role). "Share access to notes" means shared **Job** and **Item** timelines and text notes—not a separate siloed note product: the collaboration surface is the same entities as the app today, backed by sync.
4. **Pro pipeline features** — voice **transcription** (recordings → readable text notes; see [§17.7](#177-voice-transcription-as-readable-notes-phase-2)), **AI summaries**, advanced templates, audit-friendly exports — only where they clearly support evidence + handoff; no feature sprawl.

Users who never create a workspace and never sign in **never pay** and **do not upload job content to our servers** (local-only use only).

### 17.3 Team model (multiple users, one subscription)

- **Workspace** — the billable root. Has a name, billing owner, subscription status, and retention policies.
- **Members** — human users identified by email (magic link, OAuth TBD). A member can belong to one or more workspaces in the long run; Phase 2 v1 can start with **one workspace per user** if that reduces scope.
- **Roles (initial sketch)** — at minimum **Owner** (billing + delete workspace), **Admin** (invite/remove members, manage jobs), **Member** (create/edit captures on allowed jobs), **Viewer** (read-only, e.g. client or PM). Exact matrix is an implementation detail; the design requirement is **shared access with least privilege**, not "everyone is admin."
- **Invites** — Owner/Admin invites by email; invitee installs the free app (or uses web), signs in, and joins the workspace. Devices then opt into **sync** for that workspace's data.
- **Personal vs. workspace jobs** — open design question: either (a) user moves/creates jobs **inside** a workspace to share them, or (b) jobs stay personal until explicitly "linked" or "published" to a workspace. Pick one in implementation; both preserve that **unsynced jobs stay on the device** until the user exports or enables sync.

### 17.4 Technical sketch (high level)

- **Auth** — standard session/JWT or equivalent; passwordless-first fits the contractor audience.
- **Billing** — App Store / Play subscription tied to workspace or to a "family" SKU that maps server-side to N seats; web-only teams may need Stripe or equivalent. **RevenueCat** (or similar) is a likely consolidation layer across mobile stores.
- **API + sync** — REST or GraphQL plus blob storage (S3-compatible) for media; sync protocol can start as **per-job sync** or full-workspace replication. Phase 1 zip exports stay a human handoff format only; structured interchange lives in the sync API, not in export sidecars.
- **Dashboard** — separate deployable (`web/` in [§11.1](#111-repository-layout-monorepo)); shares types/contracts via `shared/` when introduced.
- **Privacy (sync users)** — encryption in transit and at rest; workspace isolation; clear **export and deletion** for workspace data. Messaging: **local-first by default**; cloud sync is **opt-in** and covered in the privacy policy (what we store, retention, who can see workspace jobs).

### 17.5 Relationship to Phase 1 code and repo

Phase 2 **extends** the monorepo: `services/*`, `web/`, and app changes for sign-in and sync live alongside Phase 1. The Flutter app gains **optional** network modules; repositories may become "local + remote" behind the same interfaces ([§12](#12-future-proofing-for-phase-2-paid-tier)). Phase 1 builds and tests remain **fully offline** in CI so the free path never regresses.

### 17.6 Explicitly still out of scope for Phase 2 v1 (examples)

To avoid scope creep in the **first** cloud release: real-time co-editing presence, comments threads on items, arbitrary external sharing links with ACLs, enterprise SSO, and multi-region data residency can wait until **Phase 2+** unless a customer pulls us there.

### 17.7 Voice transcription as readable notes

- **Goal:** on the **web dashboard**, teammates can **read** what was said on a job without scrubbing through every clip. Transcription is a **paid / cloud** feature — not native STT in the Flutter app.
- **Phase 1 (*implemented*):** voice notes are **audio only** (plus caption/tags). No transcript column in local SQLite, no transcript UI, no platform speech APIs in the app. Users who want readable spoken text on the phone add a **text note** (OS keyboard dictation is fine).
- **Phase 2 (paid / cloud):** optional **“Transcribe”** (or auto-transcribe on upload) in the **dashboard**, backed by `services/transcribe/`. Transcript text is stored in the **server** data model (e.g. a `voice_transcripts` or workspace-scoped annotation table keyed by synced `item_id`) — **not** by adding `items.transcript` to the Phase 1 mobile schema. Search, edit, and PDF blocks use that cloud copy. The mobile app may **display** synced transcript later if we choose, but it does not own transcription or reserve a local column for it. The **audio file remains the source of truth**; transcript is derived data the user may **fix** on the dashboard (trade terms, names, mumbling).
