# SiteLog — High-Level Design

> Local-first field notes for contractors. Capture photos, voice notes, and tags on the job. Export a clean zip archive in seconds. **Free. Local. Private.**

---

## 1. Product Overview

SiteLog is a mobile app that helps contractors document job-site work without paperwork or cloud setup. Users create a job folder, snap photos, record voice notes, add captions and tags ("before", "during", "after", "issue", "completed", trade-specific, etc.), and export a tidy zip archive of selected items for the client.

The MVP is **free, local-only, account-less**. All data lives on the device. Sharing is done through the OS share sheet (email, SMS, AirDrop, WhatsApp, Drive, etc.). The MVP does **not** generate PDFs — that lives in the future paid web dashboard.

A future **paid subscription tier** will unlock cloud sync, a web dashboard, AI transcription of voice notes, branded PDF reports, and team sharing. The MVP is designed so this can be layered on later without re-architecting the data model.

---

## 2. Goals & Non-Goals

### MVP Goals
- One-tap capture loop on a job site (photo → caption → tag → voice note → save).
- Organize captures per **Job** with a chronological timeline.
- Export selected items as a shareable **zip archive** (photos, voice notes, notes, plus a human-readable index).
- 100% offline operation. No login, no signup, no network calls.
- Fast, robust, glove-friendly UI suitable for outdoor / job-site use.
- Cross-platform (Android + iOS) from a single codebase.
- **Validate demand.** The free MVP is a market test for the eventual paid tier. We need to learn whether contractors will install, use, retain, and ask for more — without breaking the privacy promise.

### MVP Non-Goals
- **No PDF generation.** PDF reports are a paid / web-dashboard feature.
- No cloud sync, no accounts, no multi-device.
- No team collaboration / sharing inside the app.
- No AI features (transcription, summarization).
- No web app.
- No analytics SDKs or third-party tracking.

### Post-MVP (paid tier — future)
- Optional sign-in + subscription.
- Encrypted cloud backup + multi-device sync.
- **Web dashboard** with the same data — this is where PDF report generation lives (branded, with logo / header / footer / templates).
- Voice-note transcription.
- AI summaries per job / per day.
- Team workspaces and role-based sharing.

---

## 3. Target User & Use Cases

**Primary user:** independent contractors and small crews (remodel, plumbing, electrical, framing, landscaping, painting, etc.) who need to document work for clients, change orders, or their own records.

**Key use cases**
1. *Progress documentation* — "before / during / after" photos for the client.
2. *Issue / problem evidence* — water damage behind a sink, hidden conditions, etc.
3. *Change-order justification* — visual + verbal proof of scope changes.
4. *Daily log* — a quick chronological record of what got done.
5. *Handoff report* — a single PDF/zip sent to the client when the job is done.

---

## 4. Platform & Tech Stack

- **Framework:** Flutter (Dart) — single codebase for Android and iOS.
- **Min OS:** iOS 14+, Android 8.0+ (API 26).
- **Local storage:** SQLite via `sqflite` (or `drift` for a typed wrapper) for metadata; the app's documents directory for binary media (photos, audio).
- **Camera:** `camera` package (with `image_picker` fallback for gallery import).
- **Audio:** `record` for capture, `just_audio` for playback, waveform via `audio_waveforms` or similar.
- **Zip export:** `archive` package (pure-Dart, no native deps).
- **Sharing:** `share_plus` (uses the native share sheet on both platforms).
- **State management:** Riverpod (or Bloc) — pick one and stick with it.
- **Routing:** `go_router`.
- **Permissions:** `permission_handler` for camera, microphone, photo library, storage.
- **Localization:** `flutter_localizations` + ARB files (English only at launch; structured so other languages can be added).

> Rationale for Flutter: single codebase, strong camera/media plugin ecosystem, good performance for image-heavy UIs, easy to ship to both stores from one repo.

---

## 5. Information Architecture

Bottom tab bar (3 tabs):

1. **Jobs** — list of all jobs (default landing screen).
2. **Capture** — quick-capture shortcut. Opens the camera; if no job is active, prompts to pick or create one.
3. **Settings** — storage info, default tags, default export settings, about, privacy.

> No standalone "Reports" tab in MVP. Exporting is initiated from inside a job ("Export…" / "Share Job"). When the paid web dashboard ships, that's where reports / PDFs are produced and managed.

Primary navigation flow:

```
Jobs
 └─ Job Detail (timeline of items, grouped by date)
     ├─ Item Detail (photo + caption + tags + voice note + free-text note)
     │   └─ Edit / Delete / Share single item
     ├─ Add Photo or Note  ──►  Capture screen
     │   ├─ Photo mode (camera)
     │   ├─ Voice Note mode (recorder)
     │   └─ Text Note mode
     └─ Export…  ──►  Select items  ──►  Options  ──►  Share (zip via OS share sheet)
```

---

## 6. Screens (MVP)

Screen specs derived from the mockups in `/docs`.

### 6.1 Jobs (Home)
- Header: app title, "+" button to create a new job.
- Search field; optional filter chip ("All Jobs", "In Progress", "Completed").
- List rows: thumbnail (most recent photo or placeholder), job name, address, status badge, item count, "Updated X ago".
- Tap row → Job Detail. Long-press → quick actions (rename, mark complete, delete).
- Footer reminder: *"Data is stored on your device only."*

### 6.2 New / Edit Job
- Fields: Name (required), Client name, Address, Job number (optional), Start date, End date / target, Notes, Status (`Planning` / `In Progress` / `Completed`).
- "Create" returns to Job Detail.

### 6.3 Job Detail
- Header: back, job name, address, status pill, edit button, overflow menu.
- Summary chips: total items, photos, voice notes, notes, issues (counts).
- Tabs or sections: **Timeline** (default), **Notes**, **Details**.
- Timeline: grouped by date (newest first), each row = thumbnail + time + caption preview + tag chips + overflow menu.
- Floating "+ Add Photo or Note" CTA.
- Overflow: Export…, Mark Completed, Delete Job.

### 6.4 Capture (Photo)
- Full-screen camera viewfinder with flash toggle, lens swap, zoom presets.
- Shutter button. After capture: thumbnail preview, **Retake** / **Save Photo**.
- Below preview: caption field, tag chips (preselected from job's recent tags + the standard set), and an inline "Tap to Record" voice-note button.
- Saves into the currently open job. If none, asks to pick or create one.

### 6.5 Capture (Voice Note)
- Large centered waveform + elapsed time.
- Big record / pause / stop control. Cancel and save (check) actions.
- Optional caption field below.
- A voice note can be attached to a photo, or stand on its own.

### 6.6 Capture (Text Note)
- Plain multi-line note, optional caption, tags.

### 6.7 Item Detail
- Large media area (photo or audio player with waveform).
- For photos: pinch-zoom, swipe between items in the same job.
- Below: timestamp, caption, tag chips, optional voice note player, free-text note.
- Actions: Share (single item), Add to Export, Edit, Delete.

### 6.8 Export (Share Job)
A lightweight 2-step sheet, not a full multi-screen wizard. Reachable from the Job Detail overflow menu and from item multi-select.

- Step 1 — Select items (checkbox list grouped by date with thumbnails; "Select all" by default). Selected count in footer.
- Step 2 — Options + Share:
  - Date range (optional override).
  - Sort order (oldest first / newest first).
  - Include captions, tags, timestamps, notes (toggles, all on by default).
  - Big **Share** button → builds the zip and opens the native share sheet.

> No PDF generation, no preview screen, no "saved reports" list in MVP. The zip is built on demand and handed to the OS share sheet; we don't keep a copy ourselves (kept transient in the app's cache dir and cleaned up).

### 6.9 Settings
- **Data & Storage**: total storage used, "Export all data" (zip backup of the whole DB + media), "Clear all data" (destructive, with confirmation).
- **Tags**: manage the default tag library (add, rename, delete, reorder).
- **Default Export Settings**: defaults for the toggles in the export sheet (sort order, what to include).
- **What's next** — a single, low-key row: *"PDF reports, web dashboard, cloud sync coming soon. Get notified →"* opens an external waitlist form (see §14). This is the most important validation signal we have. No nagging banners elsewhere.
- **Send feedback** — opens a `mailto:` to a dedicated address. No in-app form, no backend.
- **About**: app version, open-source licenses, privacy policy, terms.

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
  kind              (photo | voice | note)
  caption?
  body?             (text note content)
  captured_at       (defaults to created_at; user can edit)
  created_at
  updated_at

MediaFile
  id (uuid, pk)
  item_id (fk Item)
  role              (primary_photo | voice_note | attachment)
  relative_path     (under app documents dir)
  mime_type
  width?
  height?
  duration_ms?
  size_bytes
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

> No `Report` table in MVP. Exports are built on demand and handed off to the OS share sheet; the app does not persist a list of past exports. This row reappears in the schema when the paid web dashboard ships and starts generating PDFs.

### Default tag set (seeded on first launch)
`Before`, `During`, `After`, `Issue`, `Completed`. (User-extensible. Trade tags like `Plumbing`, `Framing`, `Electrical`, `Cabinets` can be suggested but not bundled by default.)

### File layout on disk
```
<app documents>/
  sitelog.db
  media/
    <job_id>/
      <item_id>/
        photo.jpg
        voice.m4a
        thumb.jpg
```

### Schema versioning
- All schema changes are managed by numbered migration steps in the SQLite layer.
- Each row carries `created_at`/`updated_at` so the future cloud-sync feature can layer a sync engine on top without changing the model.

---

## 8. Cross-Cutting Concerns

### 8.1 Permissions
Asked **just-in-time**, never up front:
- Camera — first time the camera screen opens.
- Microphone — first time the user taps record.
- Photo library — only if/when the user imports an existing photo.
- Storage — Android only, when needed for export.

Each prompt is preceded by a one-screen rationale in the app's own UI so the OS dialog doesn't come out of context.

### 8.2 Privacy & Security
- No network calls in the MVP. No analytics, no crash reporters that phone home (use local-only logs; if a remote crash reporter is added later, it must be opt-in and clearly disclosed).
- Data is sandboxed in the app's container. Optional device-biometric lock (Face ID / fingerprint) on app open is a stretch goal for MVP.
- Privacy policy lives inside the app and is bundled (no remote fetch).
- "Clear all data" is a single action and is irreversible.

### 8.3 Performance & Reliability
- Photos are downscaled for the timeline (cached thumbnails ~512px); originals are kept full-resolution for export.
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

The MVP's only export format is a **zip archive**. PDF generation is intentionally deferred to the future paid web dashboard, where it can be done with proper layout, branding, and on hardware that isn't a phone.

### Zip archive
A flat, human-readable structure so it's useful even outside the app:
```
SiteLog_<JobName>_<YYYY-MM-DD>.zip
 ├─ index.html             (single-page summary — opens in any browser)
 ├─ index.csv              (timestamp, kind, caption, tags, file references)
 ├─ job.json               (structured metadata for future re-import / web dashboard)
 ├─ photos/
 │   └─ 2026-05-13_09-15_before_kitchen-demo.jpg
 ├─ voice_notes/
 │   └─ 2026-05-13_10-42_water-damage.m4a
 └─ notes/
     └─ 2026-05-13_10-42.txt
```

- `index.html` is a static, self-contained page with the job header, items grouped by date, captions, tags, and `<audio>` tags pointing at the included voice notes. No JS, no external assets. This is the human-friendly "report" view — good enough for the MVP, and viewable on any device the user shares the zip to.
- `job.json` is the canonical machine-readable form. The future web dashboard ingests this to render proper branded PDFs server-side.

### Native share
`share_plus` invokes the OS share sheet so the user can pick email, SMS, AirDrop, WhatsApp, Drive, Files, etc. The generated zip lives in the app's cache directory and is purged after the share completes (or on next launch).

---

## 10. Visual Design

Pulled from the mockups in `/docs`. Two viable directions; **we pick one for MVP** (see Open Questions).

- **Light + warm yellow accent** (mockups 1 and 4): friendly, light background, yellow primary actions, gray neutrals. Reads as approachable / SMB-friendly.
- **Industrial dark + orange accent** ("BUILT" mockup): high contrast, dark cards, orange primary actions, strong contractor / job-site identity.

> Note: the mockups show PDF previews and a "Reports" tab. Those screens are aspirational — they correspond to the future paid web dashboard and are not part of MVP scope. Use them for visual language (typography, spacing, tag chips, timeline grouping) only.

Typography: a single clean sans-serif (e.g., Inter) at three sizes. Generous spacing. Photos are the hero — chrome stays out of the way.

Iconography: filled tab-bar icons, outlined action icons. Tag chips are rounded pills with a clear selected state.

Theming: app supports light and dark mode via a single design-token file (`AppTheme`) so the accent color and palette can be swapped without touching screens.

---

## 11. Repository & Code Architecture

### 11.1 Repository layout (monorepo)

The repository is a **monorepo from day one**, sized for the long game. Even though the MVP is just a Flutter app, the structure assumes SiteLog may grow into a full SaaS (mobile + web + backend services). No code lives in the root — only folders, top-level config, and meta files.

```
/                         (repo root — no application code)
├── app/                  Flutter mobile app (MVP)
├── services/             Backend services — placeholder until paid tier (see §11.4)
├── docs/                 Design docs, mockups, MVP brief
├── README.md             Repo overview and per-folder pointers
├── LICENSE
├── .gitignore
└── .editorconfig
```

Future additions, when they're justified by actual work — not before:

```
├── web/                  Web dashboard (paid tier; React/Next.js most likely)
├── landing/              Static one-page marketing site (waitlist, store badges)
├── shared/               Cross-language schemas (e.g. JSON Schema for the export `job.json`)
├── infra/                IaC (Terraform / Pulumi) once we have anything to deploy
└── tools/                One-off scripts, codegen, CI helpers
```

Rules of the road:
- **No code at the repo root.** Anything code-like lives under exactly one top-level folder.
- **Each top-level folder owns its own toolchain.** `app/` has `pubspec.yaml`; a future `services/api/` has its own `package.json` or `pyproject.toml`. We do not invent a global build system on day one.
- **Cross-cutting contracts live in `shared/`** when they exist (e.g. the `job.json` schema that both the mobile app emits and the web dashboard will ingest). Until then, the contract is documented in `docs/`.
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
│   ├── app/             (bootstrap, theme, routing)
│   ├── core/            (errors, utils, value objects, ids)
│   ├── data/
│   │   ├── db/          (sqflite/drift schema + migrations)
│   │   ├── repositories/(JobRepo, ItemRepo, TagRepo)
│   │   └── storage/     (media file IO, thumbnails)
│   ├── domain/
│   │   ├── models/      (Job, Item, Tag, …)
│   │   └── services/    (CaptureService, ExportService)
│   ├── features/
│   │   ├── jobs/        (list, detail, edit screens + view models)
│   │   ├── capture/     (camera, recorder, note)
│   │   ├── item_detail/
│   │   ├── export/      (selection sheet + zip builder)
│   │   └── settings/
│   └── l10n/            (ARB files)
├── test/                (unit + widget + golden tests)
├── integration_test/
├── android/
└── ios/
```

- Repositories are the only thing the UI talks to; they own SQLite + filesystem.
- View models / notifiers expose immutable state to widgets.
- Pure-Dart services (zip export, `index.html` rendering) are unit-testable without Flutter.

### 11.3 Testing

- **Unit:** repositories, services, model mapping, zip / `index.html` builder.
- **Widget:** every screen with golden tests for the main states (empty, loaded, error).
- **Integration:** capture → save → appears in timeline → export → share sheet.

### 11.4 Backend services — `services/` (placeholder for now)

`services/` exists in MVP only as an empty scaffold with a README explaining its future contents. **Nothing is built here during MVP** — the free app is offline-only by promise (§8.2). When the paid tier is greenlit (§14.5), expect roughly:

```
services/
├── api/                 Public REST/GraphQL API for the web dashboard and synced clients
├── sync/                Sync engine (likely event-sourced; ingests `job.json`-shaped payloads)
├── auth/                Auth + subscription / billing webhook handler (RevenueCat or direct)
├── transcribe/          Voice-note transcription worker (queued, async)
└── pdf/                 Server-side PDF report renderer (templates + branding)
```

Each service is its own deployable unit with its own README, dependencies, and CI lane. They share contracts via `shared/` (when it exists), not by reaching into each other's source.

### 11.5 Why monorepo (and not multi-repo)

- One source of truth for the cross-cutting export contract (`job.json` is emitted by `app/`, consumed by `services/sync/` and `services/pdf/` — they must not drift).
- One PR can touch both sides of a feature when a future change crosses the mobile/backend boundary.
- Cheaper at our scale — one repo, one issue tracker, one CI config evolving over time. We can split if/when it actually hurts.

---

## 12. Future-Proofing for the Paid Tier

The MVP must not paint us into a corner. Concretely:

- **Stable IDs:** all entities use UUIDs generated on-device, never auto-increment ints, so future sync can merge across devices.
- **Timestamps everywhere:** `created_at` and `updated_at` on every row → trivial last-writer-wins or CRDT layer later.
- **Soft delete (optional, behind a flag):** start with hard delete in MVP, but the schema reserves a `deleted_at` column for the sync era.
- **Repository abstraction:** swapping the SQLite-only repo for a "SQLite + remote" repo is a one-layer change.
- **Settings has a dormant "Account / Subscription" entry** that is hidden in MVP and flipped on when the paid tier ships.
- **Export format is documented and stable**, so the future web app can ingest old exports.

What the paid tier will add (out of scope for MVP, but mapped):
- Auth + subscription (RevenueCat or App Store / Play billing direct).
- Sync engine (most likely Supabase or a small custom service over Postgres + object storage).
- Web dashboard (sharing the data model).
- Voice-note transcription (server-side, batch).
- Branded PDF (logo, colors, header/footer, custom templates).
- Team workspaces.

---

## 13. Phasing / Milestones

**M0 — Skeleton (1 week)**
Flutter project, theming, routing, empty screens, SQLite + migrations, seed default tags.

**M1 — Jobs CRUD (1 week)**
Create/edit/delete jobs, list, search, status, persistence.

**M2 — Capture loop (2 weeks)**
Camera, photo save, captions, tags, voice notes, timeline rendering, item detail.

**M3 — Export (1 week)**
Item selection sheet, options, zip builder (photos + voice notes + notes + `index.html` + `index.csv` + `job.json`), native share via `share_plus`.

**M4 — Polish & ship (1–2 weeks)**
Settings, storage stats, clear data, permissions UX, accessibility pass, golden tests, store assets, privacy policy, beta on TestFlight + internal track.

Total target: ~5–7 weeks to a public MVP.

---

## 14. Distribution & Market Validation

The MVP exists primarily to answer one question: **is there real demand for a paid SiteLog Pro tier?** Build effort on sync, transcription, branded PDFs, and the web dashboard is only justified if the free app finds an audience first.

### 14.1 What "traction" means here

We're not chasing DAU — that's the wrong yardstick for a tool a contractor opens *on* a job, not between jobs. The signals that actually matter:

| Signal | Why it matters | Target (rough, first 3 months) |
|---|---|---|
| Installs | Reach — does the pitch land? | 1,000+ |
| Day-7 retention | Did they come back for a second job? | ≥ 25% |
| Jobs created per install (P50) | Real usage, not just "tried it" | ≥ 2 |
| Exports per install (P50) | Got value out the other end | ≥ 1 |
| Store rating | Quality bar / word-of-mouth fuel | ≥ 4.4 |
| **Waitlist signups for Pro** | Direct demand signal for the paid tier | **≥ 10% of installs** |
| Inbound feedback emails | Qualitative — what they actually want next | any, treat each as gold |

The waitlist conversion is the headline number. If 100 contractors install the free app and 15 of them voluntarily hand over an email saying "tell me when sync/PDF/web ships," that's a credible buy signal. If they install and never tap that row, the paid tier is a different product than we thought.

### 14.2 How we measure without breaking the privacy promise

The "no network, no analytics" pitch is doing real work. We do not break it.

What we **do** use:
- **App Store / Play Console organic metrics** — installs, retained users, ratings, crash-free %, search terms, country breakdown. Free, no SDK, no PII, no user-visible difference.
- **Opt-in waitlist** — a single tap in Settings opens an external form (Tally / Google Form / a static page we host). Email is given voluntarily. No backend on our side.
- **Opt-in feedback** — a single tap opens `mailto:`. Same idea.
- **Public reviews and replies** in the stores.

What we **do not** use in MVP:
- No analytics SDK (no Firebase Analytics, no Mixpanel, no Amplitude, no PostHog).
- No third-party crash reporter that phones home by default. If we want crash data, it's an explicit, off-by-default toggle in Settings (see Open Questions).
- No "tell us about yourself" onboarding fields.

This is a deliberate trade. We get less granular data than a typical app launch — but we keep the trust line clean ("Your data stays on your device"), which is itself part of what we're A/B-testing against the market.

### 14.3 Distribution plan

Phased rollout, cheapest channels first:

1. **Closed alpha (TestFlight + Play Internal)** — ~10 hand-picked contractors, recruited through personal network / r/Contractor / r/Construction / local trade FB groups. Goal: catch the obvious bugs, validate the capture loop is fast enough on real job sites.
2. **Open beta (TestFlight public link + Play Open Testing)** — a one-page landing site with the pitch, the four mockup hero shots, and "Join the beta" buttons. Push to the same communities. Goal: 100–200 beta users, dial in onboarding and permissions UX.
3. **Public launch** — App Store + Play Store. Coordinate a launch post on:
   - r/Contractor, r/Construction, r/HomeImprovement, r/Plumbing, r/Electricians, r/HandymanProfessional (read the rules of each first — most ban promotional posts, so this is "I built a free tool, would love feedback" not "I'm selling something").
   - Trade-specific Facebook groups (these are where the actual audience lives).
   - One short Show HN / IndieHackers post — secondary audience, but useful for the "tech-aware contractor" niche.
   - Twitter/X + LinkedIn for indie-maker visibility (low-yield for end users but high-yield for press / future investors).
4. **Earned coverage (cheap)** — pitch one trade publication (e.g. *Pro Tool Reviews*, *Tools of the Trade*, *Contractor Talk*) once we have a working app and a few testimonials.

We do **not** do paid acquisition during the market test. Paid traffic distorts the signal — we want to know if the product spreads on its own merits before spending a cent.

### 14.4 The landing page

A static one-pager. The job is to (a) convert visitors into installs and (b) capture emails from people who are interested but won't install (those are some of our most valuable signals).

Above the fold:
- Headline: *"Field notes for real work."*
- Sub: *"Photos, voice notes, captions, and tags — organized by job. Free. Local. Private."*
- App Store + Play Store badges.

Below:
- Three or four screenshots (lift directly from the mockups).
- The "100% Local / Private by Default / Photos + Voice / Reports in Seconds" feature strip (already in mockup 1).
- A single "Coming soon: cloud sync, web dashboard, PDF reports — get notified" form. Same form Settings → "What's next" points at. **One waitlist, two entry points.**
- A short FAQ (Is it really free? Yes. Does it work offline? Yes. Do you sell my data? We never see it. What about the web dashboard? Paid, coming after we know people want it.)

Host it on whatever's cheap and fast (GitHub Pages, Cloudflare Pages, Netlify). One domain, one page, zero JS frameworks needed.

### 14.5 Decision gate

We re-evaluate the paid tier after **3 months post-launch** with the metrics in §14.1 in front of us. Three outcomes:

- **Strong signal** (waitlist ≥ 10% of installs, retention ≥ 25%): build the paid tier as scoped — sync, web dashboard, PDF reports, transcription. Probably ~6 months of work.
- **Mixed signal** (good installs, weak waitlist, OR weak installs but strong feedback): the product is interesting but the paid pitch is wrong. Re-interview the waitlisters and the top engaged users before building anything more.
- **Weak signal** (low installs, low retention, no waitlist): keep the free app running as a portfolio piece, do not invest in the paid tier. Cheap to maintain because there's no backend.

---

## 15. Open Questions

1. **Brand & name** — confirm "SiteLog" vs. "BUILT Field Notes" (the dark/orange mockup uses a different mark).
2. **Visual direction** — light+yellow vs. dark+orange. Pick one for MVP.
3. **Biometric lock on app open** — MVP or post-MVP?
4. **Photo storage policy** — keep originals forever, or offer a "compress originals" toggle in settings to manage device storage?
5. **Single-photo vs. multi-photo item** — current model is one primary photo per item; do we want a "burst" / album-style item from day one?
6. **Edit history** — do we keep prior versions of captions/tags, or is overwrite fine for MVP? (Overwrite is fine for MVP; revisit with sync.)
7. **Crash reporting** — none in MVP, or local-only logs the user can email if something breaks?

---

## 16. Out of Scope (explicit)

To keep the MVP shippable, the following are **explicitly not in scope**:
PDF generation, accounts, login, cloud, sync, web app, team sharing, comments, push notifications, in-app purchases, transcription, AI summaries, custom report templates, logos/branding, multi-language UI, tablet-optimized layouts, Apple Watch / Wear OS companions.
