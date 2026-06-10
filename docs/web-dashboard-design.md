# Web Dashboard — MVP Design Spec

> **Job Site Records** — browser app for teams on a paid workspace. Owners manage synced job records, invite workers, and generate PDF reports from field-captured data.

**Parent doc:** [`high-level-design.md`](high-level-design.md) — product phasing, mobile data model, and privacy rules. **Do not update HLD until this spec is fully concrete** and reviewed.

**Status:** MVP design spec (draft, May 2026). Nothing in `web/` is implemented yet.

---

## 1. Goal

Build a simple web dashboard that lets a contractor:

1. **Manage synced job records** for their company workspace
2. **Invite workers** by email so each can log in and sync job data for that workspace
3. **Generate PDF reports** from field-captured photos, notes, voice, and attachments

The dashboard supports a **paid workspace model**: an owner creates a company workspace (e.g. “Smith Plumbing”), invites workers, and each worker syncs job data into that workspace. **Field capture** (camera, mic, rapid multi-shot) stays on the **mobile app**; the dashboard is for **review, organization, team admin, and professional handoff**. The dashboard may **upload** existing files (photos, PDFs) from disk in a later milestone — that is not “capture” (no live camera/mic workflow).

### Product principle

> Your crew captures job records in the field.  
> The dashboard lets the company review, organize, and turn those records into professional reports.

### UX bar (this is how we beat competitors)

Competitors in this space (CompanyCam, Buildertrend, Raken, JobNimbus, Procore) either feel like spreadsheets or take 10 minutes to do a 30-second task. **Our dashboard wins on speed and feel, not feature count.** Every screen below is judged against this bar:

| Principle | What it means in practice |
| --- | --- |
| **Instant feedback** | Every edit (caption, tag, status, assignment) updates the UI **optimistically** — no spinners, no save buttons. Rollback + toast on failure. |
| **Autosave everywhere** | No “Save” buttons on inline edits. Job metadata saves on blur or 500 ms after typing stops. |
| **One primary action per screen** | Amber CTA in the same top-right slot on every page (`+ New job`, `+ New PDF report`, `+ Invite worker`). Muscle memory matters. |
| **Keyboard-first** | `/` focuses search, `Cmd/Ctrl+K` opens a command palette (jump to job, create report, switch workspace), arrow keys navigate the photo lightbox, `Esc` closes overlays. |
| **Sub-second perceived load** | **Skeleton screens** (not spinners) on first paint. Thumbnails lazy-load progressively. List virtualization above ~50 rows. |
| **State lives in the URL** | Filters, search term, selected job, and lightbox state are reflected in URL params so refresh / share / back-button all work. |
| **No modals for routine tasks** | Inline editing on tables and timelines. Drawer or side-panel for detail when a full page change would feel heavy. |
| **Toasts over dialogs** | Confirmations are toasts with **Undo**. Destructive actions (delete report, remove member) use a single confirmation dialog and **Undo** for 5 s after. |
| **Mobile-responsive web** | **Minimum supported width: 768 px** (tablets at the job site). Below 768 px is not a target for MVP. At 768–1279 px: collapsed sidebar; single column where needed. |
| **Real-time refresh hint** | When the underlying job changes (mobile sync, another teammate), show a small non-blocking *“New activity — refresh”* pill. Never auto-jump scroll position. |

These are **MVP requirements**, not polish. If a feature ships without them, it isn’t done.

### MVP placement

The dashboard is **required for product MVP completion** (mobile + sync + dashboard). It ships in **Phase 2** alongside sync and billing. Phase 1 mobile can ship alone; this spec defines the Phase 2 web surface.

### Mockups (inspiration only)

UI mockups in `docs/` (e.g. [`dashboard-mockup-03-pdf-reports-light.png`](dashboard-mockup-03-pdf-reports-light.png)) are **aspirational visuals** — typography, spacing, color, and general “office SaaS” feel.

**This spec is authoritative for MVP.** When a mockup shows navigation, features, or flows not listed here, **ignore the mockup** and follow this document ([§3](#3-navigation), [§4](#4-pages), [§12](#12-mvp-scope)). Do not expand scope because a mockup includes Dashboard, Daily logs, client share links, notifications, etc.

---

## 2. Core concepts

### User

A person with an account, identified by **email**. A user may belong to **multiple workspaces** (e.g. a sub who works for two GCs).

### Workspace

A company/team account — e.g. **Smith Plumbing**. All synced jobs, members, branding, subscription limits, and reports belong to the workspace.

### Member

A user who belongs to a workspace. MVP supports **two roles only**:

| Role | Description |
| --- | --- |
| **Owner** | Created the workspace (or transferred ownership). Manages team, settings, reports, and plan/subscription. Full access to all workspace jobs. |
| **Member** | A worker. Contributes records via sync on **assigned jobs**. Cannot manage team, billing, or workspace settings. |

No **Admin**, **Viewer**, or **Client** roles in MVP.

### Job assignment

Jobs can have **one or more assigned members**. Assignment controls who may **edit** a job and which jobs **sync to a member’s mobile device**.

| Role | Job visibility | Job edit |
| --- | --- | --- |
| **Owner** | All workspace jobs | All workspace jobs |
| **Member** | All workspace jobs (dashboard list) | **Only jobs they are assigned to** |

Owner assigns members from the job detail page (or job edit form). Unassigned members can open a job read-only on the dashboard but cannot change job metadata, captions, tags, or items on that job.

**Mobile sync:** members sync **assigned jobs only**; owners sync all workspace jobs.

### Billing unit

Each workspace pays for its own members. If the same worker belongs to Smith Plumbing and Northside Remodels, **each contractor counts that worker** toward their own workspace member limit.

---

## 3. Navigation

### Layout (MVP)

- **Left sidebar** — app logo + MVP nav items (§3 below)
- **Top header** — workspace switcher, user menu (no notification bell in MVP)
- **Main content** — page title, subtitle, primary action button (amber accent)
- **Reports page** — list/table + preview split pane ([§4.3](#43-reports))

*Style only:* [`dashboard-mockup-03-pdf-reports-light.png`](dashboard-mockup-03-pdf-reports-light.png) — use for visual tone, not feature scope.

### Sidebar (MVP)

```
Jobs
Reports
Team
Settings
```

Photos, notes, voice, and files are **not** separate nav items — they live under **Jobs → job detail timeline**.

Plus header chrome:

- **Workspace switcher** — required when user has multiple workspaces
- **User menu** — account email, sign out

No standalone **Billing** page for MVP. Subscription management lives under **Settings → Manage subscription** → **Paddle Customer Portal** (hosted; no custom billing UI).

### Route map

| Route | Access | Purpose |
| --- | --- | --- |
| `/login` | Public | Sign in — **Google**, **Apple**, **email + password**, or **magic link** ([§11](#11-auth--sessions)) |
| `/jobs` | All members | Workspace job list (filters in URL) |
| `/jobs/:id` | All members | Job detail + timeline (edit gated by assignment) |
| `/jobs/:id?item=:itemId` | All members | Item lightbox (overlay; preserves timeline scroll) |
| `/reports` | All members | Reports list + preview pane (selected report via `?id=`) |
| `/reports?new=1` | All members | Inline report builder drawer (no separate page) |
| `/team` | **Owner only** | Members, invites |
| `/settings` | Mixed | Workspace settings (owner); account (all) |

**Routing principles:**

- Item detail is an **overlay** on top of `/jobs/:id`, not a separate page — closing it preserves your scroll position and filter state.
- Report builder is a **drawer**, not a wizard. Single pane, live preview, no Next/Back buttons.
- Filters, search, and selection live in **URL query params**: `/jobs?q=kitchen&status=in_progress&tag=issue&assignee=joe`. Refresh and shareable links just work.

### Workspace switcher

- Shown in the dashboard header whenever the user belongs to ≥1 workspace.
- **All dashboard data is scoped to the selected workspace.** Jobs from different workspaces must never be mixed.
- Example: Joe belongs to Smith Plumbing and Northside Remodels. When Smith Plumbing is selected, he only sees Smith Plumbing jobs. Switching workspace reloads all lists and detail views for Northside Remodels.

---

## 4. Pages

### 4.0 Interaction patterns (apply to every page)

Cross-cutting patterns each page in §4 inherits. **Don’t re-spec these per page** — call out only deviations.

**Editing**
- Inline edit on hover-reveal pencil or click-to-edit on text fields (job name, caption, branding fields).
- Autosave on blur or after 500 ms idle. Show a small `Saved` indicator that fades after 1 s; on error, show `Couldn’t save — retry` inline.
- Optimistic UI for tags, assignments, status changes. Roll back on error and toast.

**Lists & tables**
- **Skeleton rows** during first load. Spinners only for explicit user-triggered actions (e.g. generating a PDF).
- Sticky table headers; row hover reveals an actions menu (`⋯`).
- Bulk select via row checkbox; bulk actions bar slides up from the bottom.
- Virtualize when row count > 100.
- Empty state with a single primary action (e.g. *“No jobs yet — Create your first job”*).

**Search & filters**
- `/` global shortcut focuses the page’s primary search field.
- Search-as-you-type with 250 ms debounce.
- Filters render as **chips** that show the active value (`Status: In progress ×`). One click to remove.
- Filter and search state mirrored in the URL.

**Command palette (`Cmd/Ctrl+K`)**
- Universal jump-to: jobs by name, recent reports, switch workspace, create job, create report, invite member (owner).
- Fuzzy match; arrow keys + Enter; Esc to close.

**Lightbox (photos)**
- Arrow keys ←/→ between items in current job timeline (respects active filters).
- `Esc` closes; URL updates so back button works.
- Pinch-to-zoom on touch; scroll-to-zoom on desktop.
- Caption and tags edit inline below the image; autosave.

**Toasts & confirmations**
- Toasts top-right, auto-dismiss 4 s, never block input.
- Destructive actions show one dialog *or* offer **Undo** in a toast for 5 s — pick per action, not both.

**Loading hierarchy**
1. Cached/last-known data renders immediately
2. Skeleton for missing pieces
3. Background revalidation; soft refresh when newer data arrives
4. Hard errors → inline retry, never a full-page error if avoidable

**Responsive breakpoints**
- ≥ 1280 px: full sidebar + content + preview/drawer
- 768–1279 px: collapsed icon-only sidebar; preview becomes drawer
- **< 768 px:** not supported in MVP (may render but no dedicated layout pass)

---

### 4.1 Jobs (main screen)

List/table of **synced jobs** in the current workspace.

**Columns / fields**

| Field | Notes |
| --- | --- |
| Job name | Required |
| Client or site name | From `client_name` |
| Address | If available |
| Status | `planning` \| `in_progress` \| `completed` (matches mobile app) |
| Assigned members | Avatars or count; owner sees all assignees |
| Last updated | `updated_at` |
| Created by | Member who created/synced the job |
| Item counts | Photos, notes, voice recordings, files (attachments); optional report count |

**Search & filters**

- Search — job name, client, address, job number
- Filter by date, status, assigned worker, client, tag

**Primary actions**

| Action | Owner | Member |
| --- | --- | --- |
| Open job | ✓ | ✓ |
| Create job | ✓ | ✓ |
| Edit job metadata | ✓ (any job) | ✓ (**assigned jobs only**) |
| Assign members | ✓ | ✗ |
| Edit captions / tags / items | ✓ (any job) | ✓ (**assigned jobs only**) |

**Create job (web):** office or field lead creates the job folder (name, client, address, etc.). Opens as a **right-side drawer** (not a full page), so the list stays visible behind it. The **Site address** field uses **Google Places autocomplete** when `NEXT_PUBLIC_GOOGLE_MAPS` is configured (same formatted-address string as mobile; plain text fallback when unset). Creator is auto-assigned to the job. Owner can assign additional members. Creating a job on web does **not** replace the mobile app for capture.

**Job status:** use the same values as the mobile app — `planning`, `in_progress`, `completed`. No separate archive state; use `completed` when a job is done. Status changes inline from the row (click pill → menu) with optimistic update.

**UX details specific to this page**
- Default sort: most recently updated first.
- Status pill is **clickable** for inline status change (owners + assigned members).
- Hover row shows `⋯` actions: Open, Edit, Assign members, Mark completed, Delete (owner).
- Empty state shows two CTAs: *Create job* and *Open the mobile app* (with QR code).
- Saved view state (filters + sort) per workspace, persisted in URL + localStorage fallback.

---

### 4.2 Job detail

Timeline-style view of all records for one job. Purpose: let an office user **review and organize** field records before generating a report.

**Timeline includes**

- Photos (thumbnail + caption + tags)
- Text notes
- Voice notes (audio player)
- Timestamps (`captured_at` / `created_at`)
- Worker / author (`created_by_user_id`)
- Tags
- Attachments / files (PDFs, imports)
- **Report history** — PDFs previously generated for this job (links to `/reports/:id`)
- **Assigned members** — owner can add/remove assignees

**Layout:** date-grouped timeline (newest first), matching mobile mental model. Filter bar: search, type chips, tag chips, date range, **author** chip (who captured it).

**Edit gating:** if the current user is a member **not** assigned to this job, the page is **read-only** (no edit job, no caption/tag changes). Show a clear banner: *“You’re viewing this job. Ask the owner for assignment to edit.”*

**Web MVP UI:** view timeline; edit captions/tags and job metadata when permitted. **Mobile web (≤767px):** in-browser **photo** capture (live camera + library fallback) and **voice** recording (MediaRecorder) from **+ Add to job** — same mint/complete blob path as mobile sync. **Desktop web:** no live camera/mic yet; text notes only from **+ Add to job**. **Uploading** existing images or files from disk on desktop is **planned post-MVP**. Photo **mark-up** (annotate synced photos) is in scope per [`web-photo-annotation-plan.md`](web-photo-annotation-plan.md).

**UX details specific to this page**
- **Desktop layout (*implemented*):** polished SaaS dashboard — sidebar (280px, icons, collapse), top utility bar (workspace, search, account pill), job header (large title, address, status pill, **Refresh · Export · ⋮ · + Add to job**), **All + kind summary chips**, wide **Search timeline** row with **Filter** and **Select items**, date-grouped **card timeline** with vertical rail (same card pattern as mobile web: kind pills, photo thumbnails, overflow ⋮). Inline note compose removed; **+ Add to job** dropdown opens capture options (text note via modal; photo/voice/file app-only or coming soon on desktop). **Export job** modal (item checklist, date range, sort, include options — download stub until backend export). **Selection mode** replaces header with Tag · Export · Delete · Cancel; Escape exits. Job metadata (number/dates/notes) in collapsible details when present. **Mobile web (≤767px):** bottom nav, FAB, filter sheet; **+ Add** sheet opens photo camera, voice recorder, or text note.
- **Photos (*implemented*):** each photo is a **timeline card** (thumbnail + Photo pill + time + caption + ⋮), not a loose gallery grid. Chronological interleaving with voice, note, and file cards under date headings.
- **Lightbox (*implemented*):** click a photo → full image; footer and nav controls **shrink-wrap to image width** (no full-viewport bar on portrait shots). **Caption** is the primary footer block (tap-to-edit textarea); **metadata** (`date · time · N of M`) and **actions** (`Annotate` / `Edit annotations`, hold-to-peek hint) sit on a second row, actions right-aligned. **← / →** (buttons + keyboard) move between all photos in the job; disabled nav hidden; mark-up editor parity with mobile §6.4a; hold to peek original; `Esc` closes.
- **Caption & tags edit inline** — captions on photos edited in lightbox; **tags** editable in lightbox, note edit, capture review, and bulk select (Tag sheet with tri-state chips + create-new).
- **Tag picker** appears as a popover with type-ahead, recent tags, and create-new in one input.
- **Bulk select** in timeline: click row checkbox or shift-click range; bottom bar shows `N selected · Tag · Delete · Add to report`.
- **“New activity” pill** at the top of the timeline when sync adds items while you’re viewing — never auto-scroll the user.
- **Jump to date** picker on the timeline scrubber for long jobs.

**Deferred (post-MVP)**

- **Web upload** — add photos and files to a job from disk (file picker + caption/tags); reuses the same blob upload path as mobile sync (§15.5). Not live capture.
- **Expenses panel** — OCR roll-up of **`Receipt`**-tagged items, editable extracted fields, job cost subtotals, CSV/Excel export (§8.2)

---

### 4.3 Reports

Generate **PDFs** from job records. Also reachable from job detail (“Create PDF”).

**Layout (MVP):**

```
┌──────────┬─────────────────────────────────────┬──────────────────┐
│ Sidebar  │  Reports                            │  Preview         │
│          │  Create branded PDF reports…        │  [Download]      │
│          │  [+ New PDF report]  Template ▾     │                  │
│          │  All reports | Ready | Generating   │  PDF thumbnail   │
│          │  ┌─────────────────────────────┐   │  + filename      │
│          │  │ table: name, job, created,   │   │  + size, date    │
│          │  │ author, status               │   │                  │
│          │  └─────────────────────────────┘   │                  │
└──────────┴─────────────────────────────────────┴──────────────────┘
```

**Page chrome**

- Title: **Reports**
- Subtitle: e.g. *“Create branded PDF reports and keep a record of what was sent.”*
- Primary CTA: **New PDF report** (amber button, top right)
- **Template** dropdown — MVP: single option (default workspace branding). Named templates deferred.

**Reports list (table)**

| Column | Notes |
| --- | --- |
| Report name | e.g. “Client handoff — Smith Kitchen”; page count if known |
| Job | Job name + address (secondary line) |
| Created | Date/time |
| Author | User who generated |
| Status | **Ready** (green) \| **Generating** (spinner) \| **Failed** (red) |
| Actions | Row menu (⋯) — **download**, **delete** (owner may delete any report; member may delete reports they created — soft delete + 30-day purge per [§9](#9-backend-model)) |

**Filters:** Status filter chip (`All`, `Ready`, `Generating`, `Failed`) — keeps a single filter row consistent with Jobs. No separate tab strip; tabs and a status column duplicate the same signal.

**Preview pane (right column)**

- Selected row drives preview. First row auto-selected on page load.
- **Download** button when status = Ready (also: copy direct link, regenerate).
- Inline first-page render (not just a thumbnail) — sharp enough to verify branding without downloading.
- Filename + file size + created timestamp below preview.
- **Failed** reports show the error inline with a **Retry** button.
- Empty state when no reports yet: amber **+ Generate your first report** CTA in the preview area.

**MVP report builder — inline drawer with live preview** (no wizard)

The builder opens as a wide right-side drawer over the Reports list. Left half: form. Right half: **live PDF preview** that re-renders ~500 ms after any change. No Next/Back, no “Step 2 of 4.”

Form fields (top to bottom):

1. **Job** — autocomplete picker (defaults to current job if opened from job detail)
2. **Date range** — quick chips (*All*, *Last 7 days*, *This week*, *Custom…*); custom range opens an inline calendar
3. **Include** — checkboxes for Photos, Notes, Voice item entries, Attachments / files
4. **Item selection** — defaults to all in range; click *Refine* to open a checklist; drag to reorder (stretch — date order is the default)
5. **Branding** — locked summary line (logo, header, footer) pulled from workspace Settings, with a *Change in Settings →* link
6. **Title** — auto-generated (`{Job name} — {date range}`), editable

Bottom of drawer: **Generate PDF** (amber). After click → drawer closes, row appears in the list as **Generating**, status updates without a refresh, preview pane swaps to the new PDF when **Ready**.

**Deferred (post-MVP)**

- Include transcripts in PDF (§8.1)
- Email / share report; external client links
- Multiple saved templates beyond default
- Client portal
- Approval workflow
- Multi-job reports

**Backend:** `services/pdf/` renders; dashboard polls status; failed reports show **Failed** with retry.

---

### 4.4 Team (owner only)

| Feature | MVP |
| --- | --- |
| Active members list | ✓ |
| Pending invites | ✓ |
| Invite worker by email | ✓ (always **member** role) |
| Remove member | ✓ |
| Resend invite | ✓ |
| Show role | ✓ (owner \| member) |
| Last active date | ✓ if available from auth/sync |

Members **cannot** access `/team`. They do not see the Team nav item.

**UX details**
- Single page, single table. **Invite worker** is the primary CTA top-right; opens an inline row at the top of the table — no modal.
- Pending invites render in the same table with a muted style and **Pending · Resend** action.
- Member row shows: avatar, name (or email if no name), role pill, last active, ⋯ menu (Resend / Remove).
- When at member limit, the invite input is **disabled** with helper text *“At limit (5 / 5) — upgrade to add more”* and an inline link to Settings → Manage subscription.
- Removed members do not disappear from job history — their captures remain attributed.

---

### 4.5 Settings

**Owner-only sections**

| Section | Fields |
| --- | --- |
| Workspace | Name |
| Branding | Company logo, contact info, default report header/footer |
| Plan | Plan display name (e.g. Crew), member count `3 / 5`, member limit |
| Billing | **Manage subscription** → [Paddle Customer Portal](https://developer.paddle.com/concepts/customer-portal) |

Example plan display:

```
Plan: Crew
Members: 3 / 5
[Manage subscription]
```

Do **not** build custom invoice/payment UI, invoices page, or in-app plan changes for MVP.

**UX details**
- Logo upload: drag-and-drop zone + click-to-pick. Live preview in a small mock PDF header alongside.
- Branding fields autosave with the standard `Saved` indicator.
- All Settings fields visible at once on one scrollable page — no tab nesting.

**All members — Account section**

| Field | Notes |
| --- | --- |
| Email | Display only |
| Sign out | ✓ |
| **Leave workspace** | ✓ — self-serve disconnect (see D14). Workspace job data the user contributed **remains** on the server. Owner must **transfer ownership** or delete the workspace before leaving (cannot abandon a billed workspace). |

Members see **Account** only; workspace/branding/billing sections are hidden.

---

## 5. Invite flow

1. Owner enters worker **email** on Team page → **Send invite**.
2. Worker receives invite email with magic link.
3. Worker signs in with that email (creates account if new).
4. Worker **accepts invite** → joins workspace as **member**.
5. Owner assigns the worker to one or more jobs (or worker creates a job and is auto-assigned).
6. Worker opens mobile app → signs in → syncs **assigned jobs** for that workspace.

A worker may belong to multiple workspaces over time; each workspace bills separately for that seat.

---

## 6. Permissions

### Owner can

- View and edit **all** workspace jobs
- Create jobs and assign members
- Generate reports for any job
- Edit captions, tags, and item metadata on any job
- Invite and remove members
- Manage workspace settings and branding
- Open hosted billing portal (Manage subscription)

### Member can

- View **all** workspace jobs on the dashboard (read-only on unassigned jobs)
- Create jobs (auto-assigned as creator)
- **Edit job metadata, captions, tags, and items only on jobs they are assigned to**
- **Contribute records via mobile sync** on assigned jobs — photos, notes, voice, files
- Sync **assigned jobs** on their device
- **Generate reports** for jobs they are assigned to (decided — see §17)

### Member cannot

- Edit jobs or items they are **not** assigned to
- Assign or unassign members on jobs
- Invite or remove users
- Access Team page
- Change workspace settings or company branding
- Manage subscription or see billing portal

### Leave workspace (D14)

- **Member:** Account → **Leave workspace** → confirm → `workspace_memberships.status = left` (or removed). User loses dashboard/sync access to that workspace; **jobs and items they created stay** in the workspace for the company.
- **Owner:** cannot leave without **transferring ownership** to another member or deleting the workspace (billing + data integrity).

### Capture clarification (web vs mobile)

| Capability | Web dashboard MVP | Mobile app |
| --- | --- | --- |
| Add new photos / voice / files | **Mobile web:** photo + voice capture; **desktop:** text note only; file upload planned | **Yes** (assigned jobs only for members) |
| View timeline | Yes (all jobs) | Yes (assigned jobs for members) |
| Edit captions / tags | Yes (if assigned or owner) | Yes (if assigned or owner) |
| Create job folder | Yes | Yes |

---

## 7. Data isolation

Data is **strictly scoped by workspace**.

- Every synced query filters by `workspace_id` from the session’s selected workspace.
- A user in two workspaces never sees mixed jobs.
- **Local-context jobs** on the phone (`workspace_id` null) **never** upload. They exist only in the mobile app until the user **moves** a job into a paid workspace ([§20](#20-mobile-app-changes-required-phase-2), D17). The web dashboard **never** shows Local jobs.

**Example**

Joe belongs to Smith Plumbing and Northside Remodels.

- Viewing **Smith Plumbing** → only Smith Plumbing jobs
- Switches to **Northside Remodels** → only Northside Remodels jobs

---

## 8. Post-MVP server processing (future)

**Not in MVP.** Do not build enrichment workers, transcript UI, receipt OCR, expense exports, or related PDF toggles for the first dashboard release.

### 8.1 Voice transcription

**Future direction (when implemented):**

- Voice notes sync as `Item` with `kind = voice`.
- After a voice file lands in object storage, a **background worker** automatically runs STT — no manual “Transcribe” button required.
- Transcript text lives in a server-side `voice_transcripts` table (keyed by `item_id`, scoped by `workspace_id`) — **not** in the mobile `items` table.
- Dashboard shows transcript under voice items; search indexes transcript text; PDF builder gains an “Include transcripts” toggle.
- Mobile may display synced transcript later; transcription originates server-side.

### 8.2 Receipt OCR & job expenses

**Future direction (when implemented):**

- **Input:** all synced items on a job tagged **`Receipt`** ([HLD §6.6a](high-level-design.md#66a-capture-file--pdf-upload)) — photographed receipts, scanned PDFs, imported images. Same tag the mobile app already uses; no separate item kind.
- After receipt media lands in object storage, a **background worker** runs OCR (and structured extraction where reliable) — no manual “Scan receipt” button required, though users may **re-run** or **correct** fields on the dashboard.
- Extracted data lives in a server-side `receipt_extractions` table (keyed by `item_id`, scoped by `workspace_id`) — **not** in the mobile `items` table.
- Typical fields: vendor/merchant, transaction date, subtotal, tax, total, currency, line items (json), confidence scores, raw OCR text. User edits override extracted values.
- **Job detail → Expenses panel:** table of receipt items with extracted amounts; **job subtotals** (optionally by date range); each row links back to the timeline item / lightbox. Filter and search like the timeline.
- **Export:** downloadable **CSV** and **Excel (`.xlsx`)** expense summary for the job (one row per receipt; optional second sheet for line items). Goal is handoff to bookkeeping (QuickBooks, spreadsheets, accountant) — **not** a full accounting or invoicing product.
- Mobile may show read-only expense totals later if we choose; OCR originates server-side.

Complements mobile **`Receipt`** tagging and zip export: crew captures and tags in the field; the office gets structured costs without retyping.

Reserve the schema shapes below for when these ship; do not implement workers or UI in MVP.

---

## 9. Backend model

Server schema aligns with Phase 1 mobile ([HLD §7](high-level-design.md#7-data-model)) plus workspace scoping. Use **UUIDs** for all entity ids (sync-friendly).

### Core tables

```
users
  id
  email                  — unique; from OAuth verified email, password sign-up, or magic-link sign-up
  name?                  — from OAuth profile or optional on sign-up
  password_hash?         — null until user sets a password (OAuth-only or magic-link-only accounts allowed)
  created_at

user_oauth_identities    — linked Google / Apple accounts (§11)
  id
  user_id                → users.id
  provider               — google | apple
  provider_subject       — stable `sub` from the provider
  created_at
  unique (provider, provider_subject)

auth_refresh_tokens      — one row per active session/device (§11)
  id                     — uuid
  user_id                → users.id
  token_hash             — sha256 of opaque refresh token; index unique
  device_label?          — e.g. "Pixel 7", "Chrome / macOS"; user-visible in Account
  created_at
  last_used_at
  expires_at             — created_at + 30 days, rolls forward on rotation
  revoked_at?            — set on sign-out, password change, OAuth identity unlink, or reuse detection

workspaces
  id
  name
  owner_user_id          → users.id
  plan_sku               — internal slug, e.g. crew_5 (see §10)
  member_limit           — denormalized from plan; enforced on invite
  paddle_customer_id?    — Paddle customer for billing portal
  paddle_subscription_id? — active subscription; null if lapsed
  logo_url?
  contact_info?          — json or text fields for report footer
  report_header?
  report_footer?
  created_at

workspace_memberships
  id
  workspace_id
  user_id
  role                   — owner | member
  status                 — active | left | removed
                           — left = user self-serve leave (D14); removed = owner kicked them
  last_active_at?
  created_at

invites
  id
  workspace_id
  email
  role                   — member (only value in MVP)
  status                 — pending | accepted | expired
  token
  created_at
  expires_at?
```

### Job data (mirrors mobile + workspace scope)

```
jobs
  id                     — uuid; same id on mobile after sync
  workspace_id?          — null on phone = Local context (D17); set when in a workspace or after Move to workspace
  name
  client_name?
  address?
  job_number?
  status                 — planning | in_progress | completed
  start_date?
  end_date?
  notes?
  cover_item_id?
  created_by_user_id
  created_at
  updated_at
  deleted_at?            — soft delete; row stays for 30 days so clients can sync the tombstone, then hard-purged by nightly job

job_assignments
  job_id                 — pk part 1
  user_id                — pk part 2
  assigned_by_user_id
  assigned_at
  revoked_at?            — set when assignee is removed; row stays so phones can stop syncing the job (members keep their local copy read-only — see §15)

items                    — mobile "Item"
  id
  workspace_id
  job_id
  kind                   — photo | voice | note | file
  caption?
  body?                  — text note content
  captured_at
  created_by_user_id
  created_at
  updated_at
  deleted_at?            — soft delete; 30-day tombstone retention

media_files              — mobile "MediaFile"
  id
  workspace_id
  item_id
  role                   — primary_photo | voice_note | attachment | file
  storage_key            — object storage path
  mime_type              — must be in allowlist (§15)
  width?, height?, duration_ms?, size_bytes
  original_filename?
  status                 — pending | uploaded | failed   (pending until client confirms upload via POST /media-files/:id/complete; §15)
  etag?                  — S3 ETag set on complete; used to detect re-uploads
  created_at
  updated_at
  deleted_at?            — soft delete

tags
  id
  workspace_id           — workspace-scoped tag library (sync from mobile)
  name
  color?
  sort_order
  updated_at             — for tag-library delta sync
  deleted_at?            — soft delete

item_tags
  item_id
  tag_id
  created_at
  deleted_at?            — soft delete (so an item-tag removal can sync to other devices)

paddle_events            — idempotency for Paddle webhooks (§10)
  paddle_event_id        — pk; from webhook payload
  event_type
  workspace_id?          — resolved from custom_data
  received_at
  processed_at?
  payload                — raw json for debugging

reports                  — also doubles as the PDF worker queue (§14)
  id
  workspace_id
  job_id
  created_by_user_id
  title?
  date_from?, date_to?
  options                — json: include_photos, notes, files, …
  branding_snapshot      — json: logo, header, footer at generation time
  pdf_storage_key?       — null until status = ready
  status                 — queued | rendering | ready | failed
  error_message?         — populated when status = failed
  claimed_at?            — set by worker when it picks up the job
  worker_id?             — which worker instance owns this row
  attempts               — int, default 0; increments on retry
  created_at
  updated_at
```

> The PDF worker claims rows with `SELECT … FOR UPDATE SKIP LOCKED WHERE status='queued'`, sets `status='rendering'`, processes, then transitions to `ready` or `failed`. No separate queue table needed.

### Future tables (post-MVP — not MVP)

```
voice_transcripts        — implement when §8.1 ships
  id
  workspace_id
  item_id
  text
  created_at
  edited_at

receipt_extractions      — implement when §8.2 ships
  id
  workspace_id
  item_id
  vendor?
  transaction_date?
  subtotal?
  tax?
  total?
  currency?              — e.g. USD
  line_items?            — json array
  raw_text?              — full OCR output
  confidence?            — json per-field scores
  user_edited_at?        — set when dashboard user corrects fields
  created_at
  updated_at
```

**Rules**

- Keep `workspace_id` on all synced records; enforce in every API query.
- Enforce edit permissions via `job_assignments` for members (active = `revoked_at IS NULL`).
- Count active `workspace_memberships` against `member_limit` before accepting invites.
- All sync-bearing tables (`jobs`, `items`, `media_files`, `tags`, `item_tags`) carry `deleted_at` for tombstone propagation (§15).

### Edit conflicts

Last-writer-wins on row `updated_at` for jobs, items, captions, and tags. The server compares `client.updated_at` to the persisted row and writes the newer of the two; the API response always returns the resulting server-state row so the client can reconcile. Dashboard shows a non-blocking refresh hint if mobile updated since page load.

### Tombstone retention

Soft-deleted rows (`deleted_at IS NOT NULL`) stay queryable through the sync API for **30 days** so offline phones can pick up the deletion on their next sync. A nightly job hard-purges rows past the window and deletes any orphaned blobs in object storage.

### Media delivery

- Timeline thumbnails (~512px) — generated on upload or on demand
- Full resolution for lightbox and PDF
- Signed URLs from object storage; short TTL (download URLs **5 min**, upload URLs **15 min** — §15)

---

## 10. Billing (Paddle) & plan SKU naming

**Provider:** [Paddle](https://www.paddle.com/) — **Merchant of Record**. Paddle sells the subscription, collects payment, handles global VAT/sales tax, and issues invoices. Works for an **Iceland-based** seller without needing a Stripe account in a supported country.

**MVP billing surface:**

- **Checkout** — Paddle overlay or hosted checkout when owner upgrades / starts trial
- **Customer Portal** — “Manage subscription” in Settings (cancel, update payment method, view invoices)
- **Webhooks** — handled inline in `services/api/` (Go); updates `workspaces` from Paddle events (D6)

Do **not** build custom payment forms, invoice UI, or tax logic — Paddle owns that.

### Why SKUs still exist (app ↔ Paddle)

Paddle has its own **Product** and **Price** IDs. The app uses a stable internal **plan SKU** so entitlement logic does not break when Paddle prices change.

| Layer | What it stores | Example |
| --- | --- | --- |
| **Customer-facing name** | Settings UI | “Crew” |
| **Plan SKU** | `workspaces.plan_sku`, webhooks | `crew_5` |
| **Paddle Price ID** | Paddle dashboard, checkout | `pri_01abc…` |
| **Member limit** | Enforced on invite | `5` |

### Recommended SKU naming pattern

```
{tier}_{seat_limit}
```

| SKU | Display name | Member limit | Typical buyer |
| --- | --- | --- | --- |
| `solo_1` | Solo | 1 (owner only) | Owner-operator testing sync |
| `crew_5` | Crew | 5 | Small crew + office |
| `team_15` | Team | 15 | Multi-crew contractor |
| `business_50` | Business | 50 | Larger shop (later) |

**Rules**

- SKU is **lowercase**, **snake_case**, **immutable** once customers are on it (add a new SKU to change limits; don’t rename).
- Display name is separate — Settings shows “Plan: Crew”.
- `member_limit` includes **all active seats**: **owner + invited members** count toward the limit. Crew 5 = owner + up to 4 workers. Solo 1 = owner only (no invites).

### Paddle mapping

1. In Paddle, create **Products** (Crew, Team) with **Prices** (monthly + optional annual).
2. Maintain a server-side lookup in the Go API: `paddle_price_id → plan_sku → member_limit`.
3. At checkout, pass **`custom_data`** (or equivalent) with at least `workspace_id` so webhooks attach the subscription to the right workspace.
4. Webhooks are handled **inline in `services/api/`** (no separate webhook service for MVP):
   - Verify signature first; reject 400 on mismatch
   - Upsert into a small `paddle_events` table keyed by `paddle_event_id` (unique index) for idempotency
   - Apply state change to `workspaces` row in the same transaction
   - Respond 200 within a few hundred ms; Paddle's own retry policy covers transient failures
5. Events handled:
   - `subscription.created` / `subscription.activated` → set `plan_sku`, `member_limit`, `paddle_subscription_id`, `paddle_customer_id`
   - `subscription.updated` → plan changes (upgrade/downgrade)
   - `subscription.past_due` → workspace enters **read-only mode** for 14-day grace period (D19); pull sync still works for mobile, push and report generation blocked, dashboard shows banner with portal link
   - `subscription.canceled` → workspace stays read-only indefinitely until reactivated or owner deletes it; no data deletion from server
6. **Manage subscription** → generate Paddle **Customer Portal** session URL for `paddle_customer_id`.

### Workspace ↔ subscription model

- **One subscription per workspace** (not per user). The **owner** is the billing contact; checkout runs in owner context.
- Member invites are blocked when `active_members >= member_limit`.
- **Downgrade below current member count** (D20): the dashboard guard runs **before** opening the Paddle portal — if the target SKU's `member_limit` is below `active_members`, show *“Remove N members before downgrading”* with a link to the Team page. Paddle portal is only opened once the count is valid. This avoids relying on Paddle to enforce app-level seat rules.

### Mobile app stores (deferred)

MVP billing is **web/dashboard via Paddle**. App Store / Play in-app subscriptions are **not** in MVP scope. If added later, map store entitlements to the same `plan_sku` slugs server-side — do not fork entitlement logic.

### MVP launch tiers

Ship **three** SKUs at launch:

| SKU | Display | Limit |
| --- | --- | --- |
| `solo_1` | Solo | 1 (owner only — sync + dashboard for solo operators) |
| `crew_5` | Crew | 5 |
| `team_15` | Team | 15 |

Exact USD/EUR/ISK prices live in Paddle only. SKUs define **structure and seat limits**, not amounts.

---

## 11. Auth & sessions

Product-level summary: [HLD §17.9](high-level-design.md#179-authentication-sign-in-methods). This section is the **endpoint and schema** detail.

**Four sign-in methods** (same account, same session — user picks any one):

| Method | Flow | Best for |
| --- | --- | --- |
| **Google** | Tap **Continue with Google** → OAuth 2.0 / OpenID Connect consent → API verifies ID token → session issued | Users already signed into Google on the device; fast signup on Android and web |
| **Apple** | Tap **Sign in with Apple** → Apple ID consent → API verifies identity token → session issued | iOS users; **required by App Store** when other third-party sign-in (e.g. Google) is offered on iOS |
| **Email + password** | Enter email and password on the sign-in screen → API verifies → session issued | Users who want a familiar login every time; office staff on a shared tablet |
| **Email magic link** | Enter email → receive single-use link → tap link (app deep link or web) → session issued | Users who prefer passwordless email sign-in |

All four methods are **MVP** on **mobile and web**. Team invites and workspace-join emails may use magic links so invitees land signed in with one tap. An existing user may accept an invite via magic link **or** sign in with Google / Apple / email + password.

**Explicitly not in MVP:** enterprise SSO (SAML/OIDC beyond Google/Apple consumer flows), SMS OTP.

### Google OAuth

- **Web:** standard OAuth redirect flow; BFF completes token exchange and calls the API.
- **Mobile:** platform Google Sign-In SDK (or equivalent) obtains an ID token → `POST /auth/oauth/google` with `{ "id_token": "…" }`.
- **Server:** verify ID token against Google's JWKS (`iss`, `aud`, `exp`, `email_verified`); upsert `users` + `user_oauth_identities` (provider `google`); issue session ([D22](#18-decisions--open-questions)).
- **First sign-in:** create `users` row + auto-created workspace + session (same as other methods).

### Sign in with Apple

- **Web:** Apple JS / redirect flow.
- **iOS:** `AuthenticationServices` native sheet.
- **Android:** Apple's web flow or supported SDK where available.
- **Server:** verify identity token against Apple's JWKS → `POST /auth/oauth/apple` with `{ "id_token": "…", "user?": { "name": … } }` (name only on first Apple authorization).
- **Private relay emails:** treat `@privaterelay.appleid.com` addresses as first-class — do not require a "real" email to match another provider.

### Email + password

- **Sign up:** email (unique) + password + optional name.
- **Password rules:** minimum **10 characters**; no upper/lower/digit/symbol mix requirements; reject passwords on a small breached-password list (top ~10k). No expiry, no rotation, no security questions.
- **Sign in:** `POST /auth/login` with email + password.
- **Forgot password:** email → single-use reset token (30 min TTL) → set new password.
- Store `password_hash` on `users` using **Argon2id** (memory ≥ 64 MiB, iterations ≥ 3, parallelism 1). `password_hash` is null for magic-link-only or OAuth-only accounts until the user sets a password.

### Email magic link

- **Sign in / sign up:** `POST /auth/magic-link` with email → send link → `GET /auth/magic-link/verify?token=…` (or POST with token) → session issued.
- Tokens single-use, **15 min TTL**.
- Mobile: deep-link handler opens app and completes verify.

### Account linking (D21)

- One `users` row per person. When Google or Apple returns a **verified email** that already exists (e.g. from email + password or magic-link sign-up), **link** the OAuth identity to that user instead of creating a duplicate.
- Linking is automatic on verified-email match; no separate "connect accounts" UI in MVP.
- A user may have **multiple** sign-in paths on one account (Google + Apple + password + magic link) when emails match or when added sequentially with the same verified email.

### Sessions (all methods) — D22

- **JWT access token + opaque refresh token** (same shape for web and mobile).
  - **Access token:** signed JWT (HS256 with rotated server secret, or RS256 if multiple services), **15 min TTL**, contains `user_id`, `session_id`, `iat`, `exp`. Sent as `Authorization: Bearer …` from mobile; HTTP-only cookie on web.
  - **Refresh token:** opaque random 256-bit value, stored hashed in `auth_refresh_tokens` table (§9), **30-day TTL**, **rotates on every use** (old token invalidated; reuse detection forces sign-out of all sessions).
- `POST /auth/refresh` exchanges refresh token → new access + new refresh.
- **Per-session record** in DB lets the user see "Active devices" later and lets the server revoke a single device without invalidating other sessions.
- Same user identity on web and mobile; one user can have many concurrent sessions.
- CSRF protection on mutating web routes (double-submit cookie or `SameSite=Strict` + custom header check).
- **BFF media proxies** (`/api/media/…/download`, `/api/items/…/thumb`) refresh the session when the access cookie has expired (same as page middleware) so `<img>` loads keep working after idle tabs without a full page reload.

### Rate limits (auth)

| Endpoint | Limit |
| --- | --- |
| `POST /auth/oauth/google` | 10 per IP per 15 min |
| `POST /auth/oauth/apple` | 10 per IP per 15 min |
| `POST /auth/login` | 5 per email per 15 min; 30 per IP per 15 min |
| `POST /auth/magic-link` | 3 per email per 15 min; 10 per IP per 15 min |
| `POST /auth/forgot-password` | 3 per email per hour |
| `POST /auth/refresh` | 60 per session per minute |

Exceeding the limit returns `429` with `Retry-After`. Limits live in the Go API (in-memory token bucket per process; promote to Postgres or Redis when we run more than one API replica).

---

## 12. MVP scope

### Build now

- [ ] **Backend:** Go API service (`services/api/`) — auth, CRUD, signed URLs, webhooks, email, sync
- [ ] **Backend:** Rust PDF worker (`services/pdf/`) — Postgres queue consumer
- [ ] **Backend:** Postgres schema + migrations; MinIO/S3 wiring
- [ ] **Backend:** Lazy thumbnail endpoint with S3 caching
- [ ] **Backend:** Sync API per [§15](#15-sync-api--protocol) (pull deltas, upsert PUTs, blob mint/complete, soft-delete tombstones)
- [ ] **Backend:** Rate limits + 50 MB upload cap + MIME allowlist + server-side magic-byte check on `complete`
- [ ] **Backend:** `auth_refresh_tokens` rotation + reuse detection; `user_oauth_identities` for Google/Apple; `paddle_events` idempotency table
- [ ] Workspace switcher (multi-workspace from day one)
- [ ] Jobs list + URL-state filters + assignment display + inline status edit
- [ ] Job detail timeline + lightbox + inline caption/tag edit + bulk select
- [ ] Job assignment enforcement (member edit gating + mobile sync scope)
- [ ] Report builder (inline drawer, live preview) + PDF download + report list
- [ ] Team invites (owner only) + member limit enforcement UI
- [ ] Owner / member roles
- [ ] Workspace settings + branding + logo upload
- [ ] Plan / member limit display + SKU enforcement on invite
- [ ] Paddle checkout + Customer Portal link + webhooks (inline in API)
- [ ] **UX foundation:** autosave, optimistic updates, toasts, skeleton loaders, `/` + `Cmd+K`, responsive ≥ 768 px, reduced-motion respect
- [ ] Auth UI on web + mobile: **Continue with Google**, **Sign in with Apple**, **email + password**, and **Email me a link** (§11); forgot-password flow for the password path

### Do not build now

- **Redis** — Postgres queue covers MVP; add later only if a second use appears
- **Separate `services/auth/`, `services/sync/`, `services/webhooks/`** — collapse into Go API; split when load justifies
- **Eager thumbnail worker** — lazy on first request is enough
- Transcription (automatic background STT, transcript UI, PDF transcript toggle) (§8.1)
- Receipt OCR, job expense roll-up, CSV/Excel export (§8.2)
- Archive job status or hide/archive flows
- Admin, Viewer, or Client roles
- Client portal
- Custom billing UI, invoices page
- Approval workflows
- Advanced analytics
- Scheduling, chat, accounting integrations
- Desktop in-browser **capture** (live camera / mic on desktop web; mobile web has photo + voice capture; **file upload** from disk on desktop is planned separately)
- Real-time presence, comment threads
- Enterprise SSO
- Email/share report from dashboard (download only for v1)

---

## 13. Visual & motion design

Align with mobile Phase 1 and the light mockup aesthetic ([`dashboard-mockup-03-pdf-reports-light.png`](dashboard-mockup-03-pdf-reports-light.png)) for **look and feel only** — see [§1 Mockups](#mockups-inspiration-only).

| Element | Direction |
| --- | --- |
| **Theme** | Light gray page background, white cards/panels |
| **Accent** | Warm amber (`#F59E0B`) — primary buttons, active nav ([HLD §10](high-level-design.md#10-visual-design)) |
| **Nav** | Left sidebar; active item = amber tint + left bar |
| **Typography** | Clean sans-serif; bold page titles; muted subtitles |
| **Tables** | Light borders, sticky headers, status pills (Ready, Generating, Failed) |
| **Density** | Office-friendly; photos remain the hero on job detail |

**Motion (subtle, fast — never showy)**

| Interaction | Duration | Notes |
| --- | --- | --- |
| Drawer / lightbox open | 180 ms ease-out | Off-screen slide; no backdrop fade-in delay |
| Drawer / lightbox close | 120 ms ease-in | Faster than open — feels responsive |
| Row hover / focus | 80 ms | Background tint only; no scale |
| Toast | 200 ms in, 200 ms out | Slide + fade |
| Status pill change | Instant | No animation — feels like a real change |
| Skeleton shimmer | 1.2 s loop | Used only when content unknown |

**Reduced motion:** respect `prefers-reduced-motion`; cross-fade instead of slide.

**Accessibility (MVP requirements)**
- All interactive elements reachable via keyboard; visible focus rings.
- Color is never the only signal (status pills include text + icon).
- WCAG AA contrast for body text on light backgrounds.
- Screen reader labels on icon-only buttons.

**All pages:** Jobs list uses same table language as Reports; read-only banner on unassigned jobs for members; dark mode deferred.

---

## 14. Technical sketch

### Stack (MVP)

| Layer | Choice |
| --- | --- |
| Frontend | `web/` — **Next.js (App Router) + TypeScript** |
| API | `services/api/` — **Go** (REST/JSON; OpenAPI for client gen) |
| Background worker | `services/pdf/` — **Rust** (HTML → PDF; only async job in MVP) |
| Queue | **Postgres-backed** (`reports.status` doubles as the work queue — see §9) |
| Cache / pub-sub | **None in MVP** (no Redis) |
| Database | **Postgres** |
| Blob storage | **MinIO** in dev, **S3-compatible** in prod (signed URLs from API) |
| Email | Transactional provider (Resend / Postmark) called **inline from API** |
| Billing | **Paddle** (MoR) — checkout overlay; webhooks handled **inline in API** |
| Hosting | Dashboard at **`https://app.jobsiterecords.com`**; API at a separate host or path (e.g. `api.jobsiterecords.com`); `landing/` stays on main domain |

### Service responsibilities

**`services/api/` (Go)** — the only public-facing service:

- Auth (Google OAuth, Sign in with Apple, email + password, email magic link, forgot-password, sessions — §11)
- All CRUD: jobs, items, tags, assignments, members, invites
- Mints **signed URLs** for blob upload (mobile → S3 direct) and download
- Mobile sync endpoints (no separate `services/sync/` for MVP)
- Lazy thumbnail endpoint: `GET /api/items/:id/thumb?w=512` → resize, cache to S3, redirect (or stream)
- Paddle webhook receiver (verify signature, upsert workspace plan, idempotent via `paddle_event_id` unique index)
- Outbound email (magic links, password reset, invites) — synchronous, fail-fast with retry on the next user action

**`services/pdf/` (Rust)** — the one async worker:

- Polls Postgres for `reports.status = 'queued'` (`SELECT … FOR UPDATE SKIP LOCKED`)
- Renders branded HTML for the report (template + branding snapshot + items)
- Converts HTML → PDF (e.g. headless Chromium via `chromiumoxide`, or another pure-Rust pipeline)
- Uploads PDF to S3 (`pdf_storage_key`), sets `status = 'ready'` or `'failed'` with error message
- One stateless binary; can scale horizontally with `SKIP LOCKED` providing safe concurrency

> Rust choice rationale: prior experience renders large reports faster and with a smaller memory footprint than Node/Chromium alternatives. The HTML-first pipeline (template → HTML → PDF) keeps branding work portable across renderers if we ever swap engines.

**Future** — `services/transcribe/` (deferred, §8), only added when transcription ships.

### Cross-language contract

Go API ↔ Rust worker share **only the Postgres schema** (notably `reports`). No RPC between them in MVP.

- API inserts: `INSERT INTO reports (... status='queued', options, branding_snapshot ...)`
- Worker claims + processes; updates `status` and `pdf_storage_key`
- Dashboard polls `GET /api/reports/:id` for status changes (or short-poll the list)

Schema is the contract. Document it in `shared/` when the third language touches it.

### Why this shape

- **No Redis** — Postgres queue is fine at MVP scale; one less service to operate
- **No `services/sync/`, `services/auth/`, `services/webhooks/`** — all live inside the Go API. The doc previously sketched these as separate services; we collapse them for MVP and split only when load or team size justifies it
- **PDF is the one worker** because it's the only job that legitimately can't run inside an HTTP request
- **Thumbnails on demand** — no eager worker, no queue table for thumbs. First viewer pays a one-time ~300 ms cost; result is cached in S3 forever

### Local dev (docker-compose)

```yaml
services:
  postgres:   # 16-alpine
  minio:      # S3-compatible blob storage
  api:        # services/api (Go)
  pdf:        # services/pdf (Rust)
  web:        # web/ Next.js dev server
```

No Redis. No third-party services running locally. Migrations applied on api start.

---

## 15. Sync API & protocol

The mobile app and the dashboard talk to the **same** Go API. This section pins the contract between them. All sync endpoints live under `/api/v1/`. All requests carry the JWT access token (§11); the server resolves the workspace from URL or body and authorizes by membership.

### 15.1 Decisions summary

| # | Decision |
| --- | --- |
| D23 | **Topology: per-job sync.** The job is the unit of pull/push. Phone tracks `last_synced_at` per job, plus a small workspace-level cursor for assignments, tags, and member changes. (No single workspace-wide changelog.) |
| D24 | **Style: REST.** Endpoints are resource-oriented (`/jobs/:id`, `/items/:id`, `/media-files/:id`). No `/sync/push` envelope. |
| D25 | **Writes use upsert PUT.** Client owns the UUID; server merges by id and applies LWW on `updated_at`. Server always returns the resolved row. |
| D26 | **Blobs are direct-to-S3.** API mints a signed PUT URL; mobile uploads the bytes; mobile then calls `complete` to confirm. API never proxies bytes. |
| D27 | **Soft delete + tombstones.** Deletes go through the same upsert path with `deleted_at` set. Tombstones surface in pull responses for 30 days. |
| D28 | **Read-only edges.** Unassigned jobs, removed members, and lapsed subscriptions are **read-only**, not wiped. Local cache stays on the device. |
| D29 | **Upload limits.** 50 MB max blob, fixed MIME allowlist, voice notes capped at 10 minutes. |
| D30 | **Rate limits on sync.** Per-session and per-IP buckets at the API layer. |

### 15.2 Identity & headers

- `Authorization: Bearer <access_token>` on every call.
- `If-Match: <updated_at>` optional on `PUT`s — server returns `409 Conflict` + current server row if the client base version is stale **and** the client opts in. Default behavior (no `If-Match`) is silent LWW.
- `Idempotency-Key: <uuid>` accepted on `POST` create endpoints (refresh URLs, complete upload). The API stores the key + response hash for 24 h and replays the same response on retry.
- All timestamps are ISO 8601 UTC with millisecond precision. `updated_at` is the LWW field; server is authoritative for tie-breaks (equal timestamps → server keeps current row).

### 15.3 Pull endpoints

Pull is per-job for content, plus three small workspace-level deltas for context.

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/workspaces/:workspace_id/assignments?since=<ts>` | Owners get all jobs in the workspace; members get rows from `job_assignments` (including `revoked_at` rows so the phone knows to stop syncing). Response includes `{job_id, role, revoked_at?, updated_at}` and a `cursor` for next call. |
| `GET /api/v1/jobs/:job_id?since=<ts>` | Job + nested `items`, `item_tags`, and `media_files` **metadata** changed since `ts`. If `since` is omitted, full payload. Tombstones (`deleted_at` set) are included. Returns `404` if the caller has no active assignment (and isn't owner). Returns `200` with `read_only: true` if the assignment is `revoked` or the workspace is lapsed — body still contains the snapshot so the phone can keep showing it. |
| `GET /api/v1/workspaces/:workspace_id/tags?since=<ts>` | Workspace tag library deltas. |
| `GET /api/v1/workspaces/:workspace_id/members?since=<ts>` | Active members + role + `left_at?` / `removed_at?`. Used by mobile to show "no longer a member" badges and by the dashboard team page. |

Pagination: each endpoint returns `next_cursor` (server-generated opaque string) when more rows exist. Page size capped at 500 rows.

**Media bytes** are *not* in pull payloads — clients fetch them via `GET /api/v1/media-files/:id/download` (§15.5) when they actually need to display or include them.

### 15.4 Push endpoints (upsert)

```
PUT  /api/v1/jobs/:job_id                       — upsert job
PUT  /api/v1/jobs/:job_id/items/:item_id        — upsert item
PUT  /api/v1/items/:item_id/tags                — set tag list { tag_ids: [uuid, …] }
PUT  /api/v1/workspaces/:workspace_id/tags/:tag_id  — upsert tag (workspace-scoped only)
DELETE /api/v1/jobs/:job_id                     — soft delete (sets deleted_at); equivalent to PUT with deleted_at set
DELETE /api/v1/items/:item_id                   — soft delete
DELETE /api/v1/media-files/:id                  — soft delete (blob purged with row at 30-day TTL)
```

Request body for upserts mirrors the row schema (§9) and **must** include the client's `updated_at`. The server:

1. Checks the caller is owner of the workspace **or** has an active assignment on the job.
2. Compares `client.updated_at` vs persisted `updated_at`; writes the newer.
3. Returns `200` with the resolved server-state row.
4. Returns `403` if the caller no longer has write access (unassigned, removed, or workspace lapsed) — the client converts the local row to read-only.

### 15.5 Blob upload & download

Two-step upload, direct-to-S3:

```
POST /api/v1/items/:item_id/media-files
  body: { role, mime_type, size_bytes, original_filename?, width?, height?, duration_ms? }
  →  { media_file_id, upload_url, storage_key, expires_at, max_size_bytes, allowed_mimes }
        (creates the media_files row with status=pending; upload_url is a signed S3 PUT, 15 min TTL)

PUT <upload_url>           — client uploads bytes directly to S3 with the correct Content-Type and Content-Length

POST /api/v1/media-files/:id/complete
  body: { etag, size_bytes }
  →  { media_file: { …, status: "uploaded" } }
        (server HEADs the object, verifies size and MIME against magic bytes, sets status=uploaded; on mismatch, status=failed and the client may retry from step 1)
```

Download:

```
GET /api/v1/media-files/:id/download[?inline=1]
  → 302 redirect to signed S3 GET URL, 5 min TTL
```

Thumbnails stay on the existing lazy endpoint `GET /api/items/:id/thumb?w=512` (§14).

### 15.6 Move local job to workspace

```
POST /api/v1/workspaces/:workspace_id/jobs/:job_id/import-from-local
  body: { job, items, item_tags, media_files_metadata }   — full snapshot of the local job
  →  { job_id, upload_urls: [ {media_file_id, upload_url, …} ] }
```

Server creates the workspace-scoped rows in one transaction, returns upload URLs for any blobs not yet on S3, and auto-assigns the uploader. The phone then runs the standard `PUT` upload + `complete` flow per media file. The local copy becomes a workspace-synced job on success. **One-way** for MVP (D31) — moving between workspaces is post-MVP.

### 15.7 Conflict & error model

- **Conflict (`409`)** — only returned when the client sent `If-Match` and the version was stale. Body: `{ error: "stale", current: <server row> }`.
- **Forbidden (`403`)** — caller no longer has access (unassignment, removal, lapsed plan). Body: `{ error: "read_only" | "no_access", reason: "<short>" }`. Client converts the local entity to read-only and stops pushing it.
- **Gone (`410`)** — the entity was hard-purged after the 30-day tombstone window. Client drops the local row.
- **Payload too large (`413`)** — blob exceeds `max_size_bytes` or media metadata claims a size over the limit.
- **Unsupported media (`415`)** — MIME outside the allowlist (table below).
- **Rate limited (`429`)** — `Retry-After` header set; client backs off per §15.9.
- **Server error (`5xx`)** — client retries with exponential backoff (§15.9).

All errors use a uniform envelope: `{ "error": "<code>", "message": "<human>", "details": {…} }`.

### 15.8 Upload limits (D29)

| Limit | Value |
| --- | --- |
| Max blob size | **50 MB** |
| Max voice note duration | **10 minutes** (mobile enforces locally; server rejects on `complete` if `duration_ms` exceeds) |
| Max items per job | 5,000 (soft cap — alert; not a hard reject) |
| Max attachments per item | 20 |

**MIME allowlist** (mobile and server both enforce; anything else is `415`):

| Kind | Allowed MIME |
| --- | --- |
| Photo | `image/jpeg`, `image/png`, `image/heic`, `image/heif`, `image/webp` |
| Voice | `audio/m4a`, `audio/mp4`, `audio/aac`, `audio/wav`, `audio/x-m4a` |
| File | `application/pdf`, `text/plain`, `text/csv`, `image/*` (same set as Photo) |

No video, archives, executables, or office docs in MVP. (Notes are text-only on the server — no blob.)

### 15.9 Rate limits (sync)

Token bucket per session, refilled per minute. Enforced inside the Go API.

| Endpoint group | Per session | Per IP |
| --- | --- | --- |
| Pull (`GET /jobs/:id`, deltas) | 120 / min | 600 / min |
| Push (`PUT /jobs`, `PUT /items`, etc.) | 120 / min | 600 / min |
| Upload mint (`POST …/media-files`) | 60 / min | 300 / min |
| Complete (`POST …/complete`) | 60 / min | 300 / min |
| Download mint (`GET …/download`) | 240 / min | 1,200 / min |

Over-limit: `429` with `Retry-After`. Clients use exponential backoff starting at 5 s, doubling to a 30 min cap, with full jitter.

### 15.10 Versioning

Sync API is versioned in the URL (`/api/v1/`). Breaking field semantics → bump to `/v2`. Additive changes (new optional fields, new endpoints) stay on `v1`. The mobile app sends `X-Client-Version: <semver>` so the server can warn-and-still-serve old builds for a window before hard-cutting them off.

---

## 16. Delivery slices (proposed)

Order rule: ship the **collaboration stack** first (auth → read → write/sync → team → harden), then the **monetization stack** (reports → billing) on top. The free-ish/internal-test surface is usable end-to-end by W4; reports and billing layer on without re-touching the core flows.

| Slice | Backend (Go API + Rust PDF) | Frontend (`web/` Next.js) |
| --- | --- | --- |
| **W0** | Repo scaffolds: `services/api/` (Go), `services/pdf/` (Rust); Postgres + MinIO via docker-compose; auth (**Google**, **Apple**, **email + password**, **magic link**, forgot password) with **JWT + refresh** (D22, `auth_refresh_tokens`, `user_oauth_identities`); workspace CRUD; leave-workspace API | `web/` shell, login (all four auth methods), workspace switcher, empty jobs list, **UX foundation** (toasts, skeletons, **command palette**, autosave plumbing) |
| **W1** | Per-job pull APIs ([§15.3](#15-sync-api--protocol)); signed-URL download; **lazy thumbnail endpoint** | Jobs list + job detail timeline (read-only) + lightbox |
| **W2** | Upsert PUT APIs ([§15.4](#15-sync-api--protocol)); member edit gating; blob mint/complete ([§15.5](#15-sync-api--protocol)); soft-delete + tombstones; assignment endpoints | Job create/edit drawer, assignments, member edit gating, inline caption/tag edit, bulk select |
| **W3** | Invite/membership APIs; member-limit enforcement; **Move local job to workspace** ([§15.6](#15-sync-api--protocol)) | Team invites + owner/member gates + member-limit UI |
| **W4** | Hardening — sync + auth rate limits ([§15.9](#15-sync-api--protocol), §11), MIME magic-byte validation, observability, uniform error envelopes | Polish — responsive layout, a11y pass, error states, real-time refresh hints |
| **W5** | `reports` table + queue semantics; Rust PDF worker renders HTML → PDF; report status API | Reports page (§4.3) — list, status filter, preview pane, builder drawer with live preview, download |
| **W6** | Paddle webhooks (inline) + `paddle_events`; branding endpoints; Customer Portal session API; **lapse → read-only** mode (D19) | Settings, branding, plan display, Paddle portal link, lapsed-plan banner |

**Why this order**

- **W0–W2** stand up the core data plane (auth, per-job sync, blobs). Mobile Phase 2 work can start integrating against W1/W2 as soon as those endpoints land.
- **W3** adds the team surface (invites, member limits, move-from-local). At this point the whole multi-user capture+sync loop works end-to-end without reports or money changing hands — perfect for internal dogfooding and closed beta.
- **W4** hardens the collaboration surface (rate limits, error envelopes, a11y) **before** we layer revenue on top, so reports and billing land on a stable base instead of fighting it.
- **W5** delivers the PDF deliverable — the headline "what subscribers actually get" — independent of payment plumbing. Reports work for any active workspace.
- **W6** wires in Paddle. Putting billing last keeps the iteration loop short (no checkout coupling during the long collaboration build) and matches a sensible launch path: internal beta after W4, friends-and-family with manual entitlements after W5, public launch after W6.

Transcription moves to a **post-MVP slice (W7+)** when prioritized — adds `services/transcribe/` (Rust or Python) and `voice_transcripts` table.

---

## 17. Milestones (user-testable states)

The slices in [§16](#16-delivery-slices-proposed) are engineering work units. **Milestones** are user-testable states — at the end of each milestone you can open the app and exercise it end-to-end for the listed capabilities. Think of slices as *what gets built next* and milestones as *what we ship next for review*.

Each milestone has a **demo script** (what you can actually do) and a **deliberately missing** list (so reviewers know what *not* to test). The order matches §16: collaboration first, monetization last.

### M0 — Clickable shell (no real backend)

**What works**

- Open `https://app.jobsiterecords.com` (or local docker) → dashboard shell renders: left sidebar (**Jobs**, **Reports**, **Team**, **Settings**), top header, workspace switcher dropdown.
- Each page shows its **real empty state** with the production visual design (light theme, amber accent, typography per [§13](#13-visual--motion-design)).
- Sign-in screen renders **Continue with Google**, **Sign in with Apple**, **email + password** fields, and **Email me a link**. Submitting shows a stub success — **does not** create a session.
- Command palette opens with `Cmd/Ctrl+K` and lists placeholder commands.

**Demo script**

1. Walk through every page in the nav and confirm the layout/typography matches the spec.
2. Resize the window down to 768 px and back up — layout adapts.
3. Open command palette, browse the placeholder commands.

**Deliberately missing:** real auth, real data, real sync.

**Backed by:** frontend portion of slice **W0** only (UX foundation, design system, routing). Backend is scaffolded but most endpoints return 501.

---

### M1 — Real authentication

**What works**

- Sign up / sign in via **email + password** → row in `users` + auto-created workspace + session.
- Sign up / sign in via **Google** → row in `users` + `user_oauth_identities` + auto-created workspace + session.
- Sign up / sign in via **Apple** (same outcome; private relay email supported).
- Sign up / sign in via **magic link** (deep-link to email; click → signed in).
- **Forgot password** works for email + password accounts.
- **Account linking:** magic-link or password account then Google with same verified email → single user, both identities linked.
- Header shows "Signed in as …" with sign-out menu.
- Session survives browser restart (JWT + rotating refresh token, [D22](#18-decisions--open-questions)).
- Hitting the rate limit on `POST /auth/login` or `POST /auth/magic-link` returns a clean `429` with `Retry-After`.

**Demo script**

1. Create an account four ways (email + password, Google, Apple, magic link on fresh emails); sign out of each.
2. Click **Forgot password**, reset, sign in with the new password.
3. Sign in with magic link, then sign in with Google using the **same email** — confirm one account, not two.
4. Refresh the page after 20 minutes; you stay signed in (refresh-token rotation).
5. Spam-click "Send magic link" five times — fifth attempt is rate-limited with a clear message.

**Deliberately missing:** no jobs yet. The Jobs page shows "no jobs in this workspace" — but for a real reason, not as a stub.

**Backed by:** rest of slice **W0** (backend auth, `auth_refresh_tokens`, `user_oauth_identities`, workspace CRUD, leave-workspace API).

---

### M2 — Single-user dashboard CRUD

**What works**

- "**+ New job**" opens the drawer form ([§4.1](#41-jobs)); creating a job shows it in the Jobs list and on Job detail.
- On Job detail, add a **text note** item with caption + tags — appears immediately in the timeline (optimistic + autosave).
- Inline-edit caption / tag / status / job metadata. Autosave fires with a quiet toast.
- Bulk-select items + apply a tag.
- Soft-delete a job / item; tombstone visible to the (eventual) sync API but hidden in the UI.

**Demo script**

1. Create 3 jobs with different statuses and addresses.
2. On one job, add 5–10 text notes across two days. Verify date grouping.
3. Edit one caption inline; refresh; edit persists.
4. Bulk-tag two items as `Follow-up`.
5. Delete a job; confirm it disappears from the list.

**Deliberately missing:** no mobile sync, no photo/voice/file capture from the web (out-of-scope per [§12](#12-mvp-scope)), no PDF reports, no teammates.

**Backed by:** slices **W1** (read APIs + read UI) and **W2** (write APIs + edit UI). The sync endpoints exist on the server but the only client today is the dashboard.

---

### M3 — Mobile metadata sync (text content first)

**What works**

- Flutter app gains the optional sign-in screen ([§20 M1](#20-mobile-app-changes-required-phase-2)).
- After sign-in, **workspace switcher** appears in the app chrome with **Local** + the user's workspace.
- Pick the workspace. Create a job + text note on the phone. Within seconds it appears on the dashboard.
- Edit the caption on the dashboard. Pull-to-refresh on the phone → edit appears.
- Edit the same caption on both sides simultaneously → LWW resolves silently; later write wins.
- Mobile Settings → Sync shows *"Last synced 12s ago · 0 pending"* and the **"Sync over: Wi-Fi only / Wi-Fi & mobile data"** toggle ([D33](#18-decisions--open-questions)).
- Sign out on the phone leaves the cached data on disk; sign back in resumes from the cache.

**Demo script**

1. On a clean phone install, sign in as the M1 user.
2. Switch context to your workspace; create a job; add a text note.
3. Open the dashboard in a second window — the job and note appear within 5 s.
4. Edit the caption on the dashboard; pull-to-refresh on the phone; your edit shows.
5. Sign out and sign back in on the phone — cached data is still there before the next sync.

**Deliberately missing:** photos / voice / files don't sync yet (no blob path). They can still be captured locally; they just don't upload. No teammates.

**Backed by:** mobile capabilities M1–M5, M7, M8 from [§20](#20-mobile-app-changes-required-phase-2); backend pull/upsert paths from slice **W2**.

---

### M4 — Media sync (photos, voice, files)

**What works**

- Capture a photo on the phone → mobile sync engine creates the `media_files` row via `POST /items/:id/media-files`, gets a signed S3 URL, uploads bytes **directly to MinIO/S3**, calls `complete` ([§15.5](#15-sync-api--protocol)).
- Within seconds, the thumbnail appears in the dashboard timeline (lazy thumbnail endpoint).
- Click thumbnail → full-resolution lightbox.
- Voice items show an inline `<audio>` player; file items show an icon + Download link.
- Wi-Fi-only toggle actually defers blob uploads when on cellular (metadata still syncs).
- 50 MB cap and MIME allowlist are enforced both client- and server-side ([D29](#18-decisions--open-questions)).
- "N pending" counter ticks down as uploads complete; failed uploads surface with retry.

**Demo script**

1. Take 10 photos and 1 voice note on the phone for an existing job; flip the phone to airplane mode mid-capture, then back online — uploads resume.
2. Confirm thumbnails and audio appear on the dashboard.
3. Flip Settings → Sync to "Wi-Fi only"; switch the phone to mobile data; take another photo → metadata syncs but blob stays pending. Switch back to Wi-Fi → blob uploads.
4. Try to upload a 60 MB file via the phone (or paste a `> 50 MB` blob into the mock client) — expect a clear error.
5. Try an unsupported MIME (`.exe` or `.mov`) — server rejects on `complete`.

**Deliberately missing:** still single user. No invites. No PDFs.

**Backed by:** rest of slice **W2** (blob mint/complete, soft delete, tombstones).

---

### M5 — Teams (invites + assignments + multi-user)

**What works**

- Owner opens **Team** → invites a teammate by email → invite email with magic link.
- Teammate signs up via the invite link → lands in the workspace as a **member**.
- Owner opens a job → assigns the member.
- Member's phone now syncs **only assigned jobs** ([§20 M6](#20-mobile-app-changes-required-phase-2)).
- Member sees **all** workspace jobs on the dashboard list but unassigned jobs are read-only with a banner ([D2](#18-decisions--open-questions)).
- Member self-leaves the workspace from Account → captures stay in the workspace.
- Owner unassigns the member → member's local copy of that job stays on the phone in read-only mode ([D28](#18-decisions--open-questions), M9b).
- "+ Invite" is disabled at the member limit (admin SQL sets `member_limit` for now).
- **Move local job to workspace** ([§15.6](#15-sync-api--protocol)) works on the phone: a Local job is promoted to the workspace; the owner sees it appear.

**Demo script** *(needs 2 phones + 2 browsers, or 2 people for ~30 min)*

1. Owner invites Member; Member accepts and signs in on phone B.
2. Owner creates Job-A and assigns Member; Owner creates Job-B without assigning.
3. Member's phone: only Job-A syncs; dashboard shows both jobs but Job-B is read-only.
4. Member adds a note + photo to Job-A on the phone; Owner sees them within seconds.
5. Owner unassigns Member from Job-A; Member's local copy goes read-only with a banner; no further sync for that job.
6. Member creates Job-C in **Local**, then "Move to workspace" → it appears in the Owner's dashboard.

**Deliberately missing:** no payment — `member_limit` is set manually via admin SQL.

**Backed by:** slice **W3**.

---

### M6 — Hardening (closed-beta-ready)

**What works**

- All errors use the uniform envelope from [§15.7](#15-sync-api--protocol). The dashboard renders friendly messages.
- Sync + auth rate limits ([§15.9](#15-sync-api--protocol)) return `429` + `Retry-After`; mobile honors back-off.
- Server validates **MIME magic bytes** on `complete`, not just headers, so a spoofed `.exe → image/png` is rejected.
- a11y pass: full keyboard nav, focus rings, `aria-*` on tables/drawers/menus, screen-reader pass.
- Reduced-motion preference respected (animations from [§13](#13-visual--motion-design) collapse to fades).
- "New activity" refresh pill appears on the Job detail page when someone else changes the job.
- Every request has an `X-Request-Id`; mobile error toasts include it so logs are findable.

**Demo script**

1. Run an axe-core / Lighthouse a11y pass — no critical issues.
2. Hammer `/api/v1/jobs/:id` from a script — rate-limit kicks in cleanly.
3. Two browsers open the same job; one edits → the other sees the refresh pill within ~5 s.
4. Tamper with a `complete` payload (claim PNG but upload an executable) — server rejects with a clear MIME error.

**Deliberately missing:** PDFs and billing still come later. Beta users get free use with admin-set entitlements.

**Backed by:** slice **W4**. **Closed beta launches here** (5–10 friendly crews, manual entitlements).

---

### M7 — PDF reports

**What works**

- Job detail → "**+ New PDF report**" opens the inline drawer ([§4.3.3](#4-pages)).
- Pick item types, date range, branding; live preview updates as options change.
- Generate → Rust PDF worker claims the row (`SKIP LOCKED`), renders HTML → PDF, uploads to S3, sets `status = ready`.
- Dashboard polls; "Ready" badge appears; Download → branded PDF.
- Members can generate PDFs for assigned jobs ([D1](#18-decisions--open-questions)).
- Reports list page works — search, status filter, preview pane, delete (owner any, member their own).
- Failed reports show the worker's error message and offer retry.
- P50 generation time on a 20-item job is under 10 s ([§18 success metrics](#18-success-metrics)).

**Demo script**

1. From a job with 20 items, generate a PDF; download and open it — branding, timeline, photos all render.
2. Generate a second report with photos toggled off; confirm a smaller, text-only PDF.
3. Force a failure (e.g. malformed logo URL in branding) → "Failed" status with a useful message.
4. As a member, generate a report on an assigned job; confirm it works. Confirm the member cannot generate one on an unassigned job (button disabled with explanation).

**Deliberately missing:** billing — `plan_sku` is still set manually.

**Backed by:** slice **W5**. **Beta users now produce real client-facing deliverables.**

---

### M8 — Paddle billing → public launch

**What works**

- Owner opens Settings → "Upgrade" → Paddle overlay checkout for `solo_1` / `crew_5` / `team_15`.
- Successful checkout fires the inline webhook → `workspaces.plan_sku` + `member_limit` updated → `paddle_events` row written (idempotent via unique index).
- "Manage subscription" opens the Paddle Customer Portal session.
- `subscription.past_due` flips the workspace into the **14-day read-only grace period** ([D19](#18-decisions--open-questions)): pull sync still works on mobile, push and report generation blocked, dashboard shows a banner with portal link.
- `subscription.canceled` leaves the workspace read-only indefinitely until reactivated; **no data deletion**.
- Downgrade with too many members: blocked **in the dashboard** before the portal opens, with a "Remove N members first" message ([D20](#18-decisions--open-questions)).
- Replaying a Paddle webhook is a no-op.

**Demo script**

1. Upgrade a test workspace to `crew_5` via Paddle sandbox checkout; confirm `member_limit` jumps to 5 and an invoice shows in the portal.
2. Use Paddle's "send test webhook" to simulate `past_due` → workspace enters read-only mode; mobile blocked from pushing; dashboard shows the grace banner.
3. Reactivate via the portal → full access restored.
4. With 4 active members on `crew_5`, attempt to downgrade to `solo_1` → dashboard blocks with the right message before opening the portal.
5. Replay any webhook from earlier → no double-apply.

**Deliberately missing:** App Store / Play in-app billing (deferred). Transcription, receipt OCR (post-MVP, [§8](#8-post-mvp-server-processing-future)).

**Backed by:** slice **W6**. **MVP complete and publicly launchable.**

---

### Milestone → slice → mobile map

| Milestone | Slices | Mobile work ([§20](#20-mobile-app-changes-required-phase-2)) | User-facing capability gained |
| --- | --- | --- | --- |
| **M0** | W0 (FE only) | — | "Here's what the dashboard will look like." |
| **M1** | W0 (BE auth) | — | Real accounts. |
| **M2** | W1 + W2 (web writes) | — | Dashboard-only CRUD demo. |
| **M3** | W2 sync APIs | M1–M5, M7, M8 (text only) | Phone ↔ dashboard sync for text. |
| **M4** | W2 blob path | media upload path | Phone ↔ dashboard sync for photos/voice/files. |
| **M5** | W3 | M6 (assignment scope), M9 (tags), M9b (read-only edges) | Two-person crew using it for real. |
| **M6** | W4 | — | **Closed beta**. |
| **M7** | W5 | — | Branded PDF reports. |
| **M8** | W6 | (paywall + lapse UI hooks) | **Paid product — public launch**. |

### Suggested external test partners by milestone

| Milestone | Test partner |
| --- | --- |
| **M0–M2** | Internal only — design + flow review |
| **M3–M4** | Internal + one friendly contractor on a real job (solo) |
| **M5** | One **two-person crew** on a real job (critical multi-user signal) |
| **M6** | Closed beta — 5–10 crews, free with manual entitlement |
| **M7** | Same beta + first PDFs delivered to actual clients |
| **M8** | **Public launch** |

---

## 18. Success metrics

| Metric | Why |
| --- | --- |
| Workspace activation | % subscribers with ≥1 synced job |
| PDFs / workspace / month | Core paid value |
| Invite acceptance rate | Team model working |
| Dashboard WAU / workspace | Office use vs phone-only |
| Jobs with ≥1 assignee | Assignment workflow adopted |
| **Time from `+ New PDF report` → Ready** | Fluid-UX bar; target P50 under 10 s for a 20-item job |
| **Inline edit success rate** | UX health — % of caption/tag edits that save without retry |
| **Lightbox sessions / DAU** | Are users actually reviewing the field record on desktop? |

---

## 19. Decisions & open questions

### Decided

| # | Decision |
| --- | --- |
| D1 | **Members can generate PDFs** for jobs they are assigned to. Branding is fixed by workspace settings (owner-controlled). |
| D2 | **Members see all workspace jobs** on the dashboard list; unassigned jobs are read-only with a clear banner. Mobile sync remains assignment-scoped. |
| D3 | **Report attachments** — included by default (photos + notes + files). User can toggle off in the builder. |
| D4 | **Item reorder** in report builder is **stretch**; date order is default and acceptable for v1. |
| D5 | **Report builder UX** — inline drawer with live preview, not a multi-step wizard. |
| D6 | **API language: Go.** REST/JSON; OpenAPI for client gen. Single `services/api/` houses auth, CRUD, sync, signed URLs, webhooks, and outbound email. |
| D7 | **PDF service language: Rust.** Worker renders HTML → PDF, polling Postgres for queued reports. Only async service in MVP. |
| D8 | **No Redis in MVP.** Postgres queue (`reports.status` + `SKIP LOCKED`) is sufficient. Add Redis only when a second concrete use appears. |
| D9 | **Thumbnails are lazy** via an API endpoint with S3 caching. No eager worker or queue job. |
| D10 | **Local dev:** docker-compose with `postgres`, `minio`, `api`, `pdf`, `web`. No Redis container. |
| D11 | **Dashboard domain:** `https://app.jobsiterecords.com` (not a path on the marketing site). |
| D12 | **Owner counts toward member limit** — yes. `solo_1` = owner only; `crew_5` = owner + 4 workers. |
| D13 | **Launch SKUs:** `solo_1`, `crew_5`, `team_15` at launch. |
| D14 | **Leave workspace** — any **member** can self-serve leave from Account; their captures **remain** in the workspace. **Owner** must transfer ownership or delete the workspace before leaving. |
| D15 | **Command palette (`Cmd/Ctrl+K`)** — **MVP**, not deferred. |
| D16 | **Responsive minimum width 768 px** for MVP; layouts optimized for tablet and desktop; phone (< 768 px) out of scope. |
| D17 | **Mobile “Local” context** — users can **always** work outside any company workspace. Display name **Local** (on-device only, no sync). Workspace switcher always includes Local + any team workspaces. |
| D18 | **Sign-in methods** — **Google OAuth**, **Sign in with Apple**, **email + password**, and **email magic link** all in MVP on mobile and web. Forgot-password flow included for the password path. See §11, [HLD §17.9](high-level-design.md#179-authentication-sign-in-methods). |
| D19 | **Subscription lapse policy** — `past_due` opens a **14-day read-only grace period** (pull works, push and PDFs blocked); `canceled` stays read-only indefinitely until reactivated. No server-side data deletion (§10). |
| D20 | **Downgrade-with-too-many-members** — guarded **in the dashboard** before opening the Paddle portal; user must remove members first. App-level rule, not Paddle-enforced (§10). |
| D21 | **Account linking** — one `users` row per person. Google/Apple link to an existing account when verified email matches (password, magic-link, or prior OAuth). Apple's private relay emails are first-class. **Password rules:** min 10 chars, breached-password list rejection, **Argon2id** hashing (§11). |
| D22 | **Sessions** — **JWT access token** (15 min) + **opaque refresh token** (30 d, rotating, stored hashed). Per-session row in DB for revocation. CSRF on web mutating routes (§11). |
| D23 | **Sync topology — per-job.** Job is the unit of pull/push; small workspace-level deltas for assignments, tags, and members (§15.1). |
| D24 | **Sync style — REST.** Resource endpoints (`/jobs/:id`, `/items/:id`); no `/sync/push` envelope (§15.1). |
| D25 | **Write semantics — upsert PUT + silent LWW** on `updated_at`; server returns resolved row. Optional `If-Match` opts a client into `409` conflicts (§15.2, §15.4). |
| D26 | **Blob uploads — direct-to-S3** with mint → PUT → complete (§15.5). |
| D27 | **Soft delete + 30-day tombstones** propagate via the same pull endpoints (§9, §15). |
| D28 | **Read-only edges, never wipe** — unassignment, leaving/removal from a workspace, and lapsed plans **all** keep cached data on the device, marked read-only. No automatic local deletion (§15.7, §19). |
| D29 | **Upload limits** — 50 MB max blob, 10-min voice cap, fixed MIME allowlist (§15.8). |
| D30 | **Sync rate limits** — token bucket per session and per IP at the API layer (§15.9). |
| D31 | **Move to workspace — one-way Local → workspace only** for MVP. Cross-workspace moves deferred (§15.6). |
| D32 | **Mobile sync triggers (MVP)** — automatic on **app foreground**, debounced after every local change (~2 s), and **manual pull-to-refresh**. **No background sync** (iOS BGTask / Android WorkManager) in MVP (§19). |
| D33 | **Network preference** — Settings toggle **“Sync over: Wi-Fi only / Wi-Fi & mobile data”** (default **Wi-Fi & mobile data**). Metadata always syncs when online; the toggle controls **blob uploads/downloads**. Sign-out **never wipes** cached workspace data (§19). |
| D34 | **Tag collisions** — no auto-merge. Workspace tags and local-only tags coexist by id; same display name simply shows both in pickers. Tag mutations on a workspace tag require workspace membership (§19). |

### Still open (dashboard)

_None — all dashboard and sync API decisions are locked (D1–D34). The remaining roadmap items are tracked in [§22 Next steps](#22-next-steps); milestones for review are in [§17](#17-milestones-user-testable-states)._

---

## 20. Mobile app changes required (Phase 2)

The dashboard MVP is **mobile + sync + dashboard**. Phase 1 ships the local-only Flutter app ([HLD §13](high-level-design.md#13-phasing--milestones)); the dashboard cannot land without these additions to `app/`. They are **Phase 2 mobile scope**, called out here so they’re not forgotten when the dashboard build starts.

### Core capabilities to add

| # | Capability | Notes |
| --- | --- | --- |
| M1 | **Optional sign-in** | **Continue with Google**, **Sign in with Apple**, **email + password**, and **Email me a link** on one sign-in screen. Users who never sign in keep **Local** forever. Deep-link handler for magic-link URLs. Forgot password → reset email. |
| M2 | **Account state** | Persist auth tokens; sign out; "Signed in as …" row in Settings. |
| M3 | **Context switcher (Local + workspaces)** | Always show **Local** plus every team workspace the user belongs to — even if they have zero workspaces (switcher still has Local). Signed-out users effectively live in Local only. Signed-in users pick **Local** or a company workspace; selection drives which jobs list and capture target apply. |
| M4 | **Sync engine** | Bidirectional per-job sync for **workspace jobs only** (`workspace_id` set), using the protocol in [§15](#15-sync-api--protocol). Last-writer-wins on `updated_at` ([§9](#9-backend-model)). Upload via signed URLs from the Go API; download via signed URLs. **No sync** while context is Local. |
| M5 | **Local vs workspace jobs** | New jobs default to the **current context**. In **Local**, jobs stay on the phone only (`workspace_id` null). In a **workspace**, jobs sync per assignment rules (M6). **Move to workspace** (D31) promotes a Local job into a chosen workspace (one-way for MVP). UI makes context obvious on every job row (e.g. no badge = Local; company name badge = synced). |
| M6 | **Assignment-scoped sync (members)** | Members only pull/push jobs they are assigned to (D2). Owners sync all workspace jobs. Unassignment (`job_assignments.revoked_at`) flips the local copy to **read-only** — see M9b. |
| M7 | **Sync status & errors** | Settings → Sync row: *Last synced X min ago · N items pending*. Tap → details, manual **Retry all**. Per-job badge when an upload is queued or failed. "Pending" = metadata not yet upserted **or** blob `status=pending` — combined count, with a sub-line *"(N with media)"* when relevant. |
| M8 | **Offline queue + retry** | Captures always succeed locally; sync happens opportunistically with exponential backoff (5 s → 30 min, full jitter; §15.9). Phase 1 capture loop must never regress. Concurrency: ≤ 3 parallel blob PUTs, 1 metadata pass at a time. On foreground: **pull first, then push**, to avoid pushing then immediately pulling an overwrite. |
| M9 | **Workspace tag library** | Pull from `GET /workspaces/:id/tags?since=` (§15.3). Workspace tags coexist with local-only tags (D34). In a workspace context, only workspace tags appear in the picker; in Local context, only local tags. Same display name simply produces two distinct rows in the picker (workspace badge vs no badge). No auto-merge. |
| M9b | **Read-only edges on device** | If a job's assignment is revoked, the workspace is left/removed, or the workspace plan lapses (D19), the local copy stays on the device, picker/editor controls disable, and a banner explains why. Background sync stops for those rows; pull may still refresh content (e.g. final read-only snapshot when plan goes `past_due`) until access is fully cut. (D28) |

### Mobile context model (D17)

Two kinds of job storage on the phone:

| Context | Display name | `workspace_id` | Sync | Visible on web dashboard |
| --- | --- | --- | --- | --- |
| **Local** | **Local** | `null` | Never | No |
| **Team workspace** | Workspace name (e.g. “Smith Plumbing”) | UUID | Per M4/M6 | Yes |

**Naming:** use **Local** in the UI (short, matches “local-first” marketing). Avoid “None” (unclear) and “Self” (sounds like a company). Internal code: `sync_context = local` or `workspace_id IS NULL`.

**Switcher behavior**

- **Always present** in the app chrome (header or Jobs tab) — not hidden when the user has only Local.
- Order: **Local** first, then team workspaces alphabetically.
- Subtitle when Local is selected: *“On this phone only — not synced”* (or icon + one-line hint).
- Switching to a workspace does **not** delete or hide Local jobs; switching back to Local shows the on-device-only list again.
- Sign-in is **not** required to use Local. Sign-in unlocks team workspaces and sync; it does **not** force the user into a workspace.

**Default context**

- **Signed out:** Local only (implicit).
- **Signed in, new install / first launch after sign-in:** default to **Local** so Phase 1 habits stay intact; user opts into a workspace when ready.
- Remember last-selected context per device (localStorage / prefs).

### Settings additions (mobile)

Today the Settings screen has Data & Storage, Tags, Default Export, "What's next" waitlist, Feedback, About. **Add:**

- **Account** — Sign in / sign out, email (context switcher lives in main chrome, not buried here)
- **Sync** — visible when a **workspace** is selected; hidden or disabled when context is **Local** (*“Select a team workspace to sync”*)
- **What's next** row stays for users who have never joined a workspace; optional when signed in but still on Local only

### What does **not** change in Phase 1

- **Local** is how the app works today. **No login, no account, no workspace** required for capture and zip export.
- Phase 1 milestones (M0–M4 in HLD §13) ship without any of the above.
- The data model is already future-proofed for sync (UUIDs, `updated_at` on every row — [HLD §12](high-level-design.md#12-future-proofing-for-phase-2-paid-tier)). No mobile schema migration is required by this spec.

### Mobile sync policy (resolved)

| Topic | Decision |
| --- | --- |
| **Sync triggers** (D32) | Foreground + debounced after every local change + manual pull-to-refresh. No background tasks (BGTask / WorkManager) in MVP. |
| **Network preference** (D33) | Settings → Sync: *"Sync over"* toggle — **Wi-Fi only** vs **Wi-Fi & mobile data** (default). Metadata syncs whenever online. The toggle only gates **blob** uploads/downloads. |
| **Move to workspace** (D31) | One-way Local → workspace via [§15.6](#15-sync-api--protocol). Cross-workspace moves deferred. |
| **Tag collisions** (D34) | No auto-merge. Workspace and local tags coexist by id; picker shows both with workspace badge for clarity. |
| **Sign-out behavior** | **Never wipe.** Cached workspace data, blobs, and pending uploads remain on device. Next sign-in (same user) resumes from existing cache; next sign-in (different user) starts fresh under a separate per-account namespace, leaving the previous user's data untouched on disk. |
| **Assignment revoked / left / removed / lapsed plan** (D28, M9b) | Local cache stays. Job becomes read-only with a banner. No further pull/push. |
| **Context switch mid-upload** | In-flight uploads for the previous context continue in the background. UI immediately switches to the newly selected context's job list. |
| **Web edits while offline** | LWW handles silently. If the user happens to be editing a row that the server overwrites, the local newer `updated_at` wins on next push (their work is preserved); a toast can show *"Synced your changes"* when push succeeds. |
| **Local sync-state schema** | Add columns to the mobile DB for `jobs`, `items`, `media_files`: `sync_state` (`synced` / `pending` / `failed` / `local_only`), `last_sync_attempt_at`, `sync_error_code?`, `remote_etag?` (blobs only). Mirrors what's pushed but stays local. |

### Open questions specific to mobile

_None — all Phase 2 mobile policy decisions are now locked (D31–D34, M9b). Detailed mobile UX (sign-in screen, workspace switcher placement, sync status indicators, "Active devices" listing) belongs in a separate mobile-side design doc when Phase 2 mobile work starts. This section enumerates **what must exist**, not how each screen looks._

---

## 21. Relationship to repo

| Folder | Role |
| --- | --- |
| `app/` | Flutter capture + sync client; assignment-scoped sync for members ([§20](#20-mobile-app-changes-required-phase-2)) |
| `web/` | Next.js + TypeScript dashboard |
| `landing/` | PHP marketing site; add “Sign in” → dashboard when live |
| `services/api/` | **Go** — auth, CRUD, sync, signed URLs, Paddle webhooks, outbound email |
| `services/pdf/` | **Rust** — HTML → PDF worker; only async service in MVP |
| `services/transcribe/` | **Future** — STT worker (post-MVP, §8) |
| `shared/` | **Future** — cross-language API contracts (e.g. OpenAPI spec) when introduced |
| `docs/high-level-design.md` | Updated **after** this spec is concrete |

---

## 22. Next steps

**Resolved in this spec:**

- [x] Mobile sync policy decisions (D31–D34, M9b; see [§20](#20-mobile-app-changes-required-phase-2))
- [x] Sync topology, write semantics, blob protocol, tombstones (D23–D27; see [§15](#15-sync-api--protocol))
- [x] Read-only edges for unassignment / leave / removal / lapse (D28)
- [x] Upload size + MIME allowlist + voice cap (D29; [§15.8](#15-sync-api--protocol))
- [x] Auth/session/JWT decisions + sign-in methods (Google, Apple, email + password, magic link) (D18, D21, D22)
- [x] Lapse + downgrade behavior (D19, D20)
- [x] Tombstone retention + 30-day purge

**Still to do (implementation, not design):**

- [ ] Configure Paddle products for `solo_1`, `crew_5`, `team_15`; document price_id → SKU map
- [ ] Point `app.jobsiterecords.com` DNS + TLS when deploying `web/`
- [ ] Wireframe Jobs list + job detail per MVP spec (mockup for styling reference only)
- [ ] Generate OpenAPI spec from the §15 contract; publish to `shared/`
- [ ] Pick Rust HTML→PDF library (e.g. `chromiumoxide` headless Chromium vs alternative); prototype on one sample job
- [ ] Define `reports` queue semantics in code (claim TTL, max attempts, failure handling) consistent with §14
- [ ] Open a mobile-side UX design doc for Phase 2 sign-in / switcher / sync indicators (covers M1–M9b)
- [x] Sync HLD §17 with the locked spec (two roles, Paddle, Go/Rust, Local context, JWT+refresh, Google/Apple/magic-link auth, per-job sync, soft-delete)
