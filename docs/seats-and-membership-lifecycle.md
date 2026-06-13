# Seats & workspace membership — lifecycle design

> How a worker goes from free local-only use, to invited, to active workspace member, to removed — and what happens to seats, data, and privacy at every step. This is the canonical narrative for the **seat / membership** model.

**Status:** Design (narrative spec) **+ implementation milestones** ([§24](#24-implementation-milestones)). Backing primitives partial in `services/api/` (workspaces, invites, seat reservation, assignment reads, `read_only`, `leave`); assign/unassign API, promotion, removal purge, and most team/seat UX not yet built.
**Created:** 2026-06-13
**Scope:** Billing/seat model, team membership, invite flow, local↔workspace boundary, multi-workspace membership.
**Related docs:** [`high-level-design.md`](high-level-design.md) §billing & §auth, [`web-dashboard-design.md`](web-dashboard-design.md) §10 (billing / SKUs) & team admin, [`sync-strategy-plan.md`](sync-strategy-plan.md) (workspace isolation & sync).

---

## 0. Core principle

A **seat belongs to the workspace subscription, not to a phone.** The paid product is a **team/workspace subscription**. Launch SKUs are `solo_1`, `crew_5`, and `team_15`, and the **owner counts toward the seat limit**. So `crew_5` means **owner + up to 4 invited workers**.

The **free/local app exists separately**: users who never join a workspace keep using local mode without paying or uploading any job content.

> The most important UX principle: **joining a workspace adds a team context, it does not replace the worker's local app.** That keeps the free/local promise intact while making the paid workspace model understandable.

### Recommended seat rules (summary)

| Rule | Recommendation |
| --- | --- |
| What is a seat? | One human member in one paid workspace |
| Does the owner count? | **Yes** |
| Does a pending invite count? | **Yes** — reserve the seat |
| Does each device count? | **No** |
| Can local users use the app without a seat? | **Yes** |
| Does login upload local data? | **No** |
| Can a worker move a local job into a workspace? | **Yes** — explicit one-way promotion |
| Who owns workspace captures? | The workspace / company |
| What happens when a worker is removed? | Access revoked; seat freed; workspace data remains |
| What happens to the worker's local jobs? | Nothing |
| Can a removed worker still use the app? | **Yes** — local mode stays free |

### MVP role model

Roles are intentionally simple for MVP: **Owner** and **Member** only.

- **Owner** — manages billing, team, and workspace settings.
- **Member** — captures/edits on **assigned** jobs; sees **unassigned** workspace jobs **read-only**.

Admin / Viewer / Client roles are **out of MVP scope**.

---

## 1. Cast

To make the model concrete:

- **Owner:** Jón, owns "Jón Plumbing ehf."
- **Plan:** Crew 5 — **5 seats total**.
- **Seats used before invite:** **1 / 5** (the owner counts).
- **Worker:** Ari, who already uses the app in **Local mode** on his phone.

---

## 2. Before invitation — the worker is in local mode

Ari has installed the app and uses it **without an account**. On his phone he sees:

- **Context: Local**
- Jobs he created himself
- Photos, notes, voice notes, files
- Zip export
- **No** team, **no** dashboard sync, **no** shared jobs
- **No** subscription prompt blocking capture

Local mode is **not a trial.** It stays free forever for basic capture, organization, and zip export. The paid product unlocks **sync, dashboard, shared team access, PDFs, transcription** — not normal phone capture.

**Nothing from Ari's local jobs has gone to the server.** Local job content stays on the device until he exports it or explicitly moves/syncs it into a workspace.

---

## 3. The owner already has a workspace

The **workspace is the billable root.** It owns the subscription, billing owner, members, workspace jobs, retention rules, and synced data.

Jón's workspace:

```
Workspace:       Jón Plumbing
Plan:            Crew 5
Seat limit:      5
Members:         1
Available seats: 4
```

Owner dashboard:

```
Team
  Jón Plumbing
  Plan: Crew 5
  Seats used: 1 / 5

Members
  Jón — Owner
```

---

## 4. The owner invites the worker

Jón goes to **Team** and enters Ari's email. The system creates a **pending invite**.

**Seat behavior — a pending invite reserves a seat.** Otherwise the owner could invite 10 people on a 5-seat plan and create confusion when the fifth person accepts.

```
Team
  Seats used: 2 / 5

Members
  Jón — Owner

Pending invites
  ari@example.com — Invited
```

Ari receives an email:

> **Jón Plumbing invited you to Job Site Records.**
> [Join workspace]

Invites are **by email**. The invitee signs in using **Google, Apple, email/password, or magic link**, and joins the workspace. Invite emails may include a **magic link** for one-tap accept.

---

## 5. The worker opens the invite

Ari taps the invite link on his phone. Two cases:

### Case A — Ari already has the app installed

The link opens the app:

> **You've been invited to Jón Plumbing**
> Join this workspace to see assigned jobs and sync your work with the team.
> [Join workspace]

He signs in. Current auth options: **email/password, magic link, Google OAuth** (Apple sign-in later).

### Case B — Ari does not have the app installed

The link opens the **web join page**:

> **Join Jón Plumbing**
> Sign in or create account

After sign-in he can use mobile web or install the app.

---

## 6. Critical moment — local data must not silently upload

Because Ari was already using local mode, this is the **most sensitive UX point**. After he joins, the app must **not** automatically upload his existing local jobs to Jón Plumbing.

Instead it shows a **context switcher**:

```
Current workspace: Local

Available:
  Local
  Jón Plumbing
```

The phone always has a **Local** context plus any workspaces the user belongs to. Ari's existing local jobs **remain local**. He now has two worlds:

| Local | Jón Plumbing |
| --- | --- |
| Ari's private/offline jobs | Team jobs |
| Not visible to Jón | Synced |
| Not billed as workspace data | Visible per role/assignment |
| Not synced unless moved | Uses the paid workspace |

This is the right privacy boundary.

---

## 7. The worker accepts and becomes a member

Once Ari accepts:

```
Owner sees:                 Worker sees:
  Team                        Workspace joined: Jón Plumbing
    Seats used: 2 / 5         Role: Member
  Members
    Jón — Owner
    Ari — Member
```

Ari now occupies one seat. **The seat is attached to Ari's user membership in the workspace, not to a device.** If Ari logs in on his phone and later on desktop web, he is still **one seat, not two**.

---

## 8. What the owner sees after the worker joins

A good owner dashboard shows per-member detail:

```
Ari
  Role: Member
  Status: Active
  Assigned jobs: 2
  Last active: Yesterday
  Seat: Occupied
```

The owner can now **assign jobs** to Ari:

```
Assign jobs to Ari:
  ✓ Smith Bathroom Remodel
  ✓ Hotel Boiler Room
```

Assignment matters because members edit **only assigned jobs** and see unassigned jobs **read-only**. The backend already supports this: owners see all jobs, members get `read_only` on unassigned jobs, and writes return **403** when the member lacks permission.

---

## 9. What the worker sees in the app

Ari switches between **Local** and **Jón Plumbing**. In the workspace context:

```
Jón Plumbing

Assigned to me
  - Smith Bathroom Remodel
  - Hotel Boiler Room

Other workspace jobs
  - Main Street Kitchen — Read-only
  - Garage Repipe — Read-only
```

For **assigned** jobs, Ari can add photos, text notes, voice notes, files (if enabled), edit his captures, tag items, and sync data.

For **unassigned / read-only** jobs he can browse but not modify. The UI blocks the write **before** the API does:

> You can view this job, but you are not assigned to it.
> Ask the owner to assign you before adding records.

The API still enforces this server-side with a **403** — client-side checks are not enough.

---

## 10. Sync behavior after joining

When Ari works inside Jón Plumbing, his captures sync to the workspace.

```
Ari opens "Smith Bathroom Remodel"
  → takes 8 photos
  → caption: "Before opening wall"
  → tags: Before, Issue
  → Save
App stores locally first.
Sync scheduler uploads metadata + media blobs to the workspace.
```

Cloud sync covers **jobs, items, media metadata, and blobs** across members' devices that join the workspace. The owner then sees Ari's new items in the desktop dashboard, mobile web, native app (if synced), and future PDF/report generation.

The owner does **not** see Ari's old local-only jobs unless Ari explicitly moves them into the workspace.

---

## 11. Moving a local job into the company workspace

Suppose Ari has a local job `Smith Bathroom Old Notes` and wants to upload it. The app offers:

> **Move to workspace**
> This will copy this local job into Jón Plumbing and sync its photos, notes, voice notes, and files. After moving, the workspace owner and assigned members may see it.
> [Move to Jón Plumbing]

Promotion is **one-way for MVP** (cross-workspace moves are post-MVP). UX rules:

- Local job stays local until explicitly moved.
- Moving creates/syncs it as a workspace job.
- The user gets a clear warning.
- After moving, the job belongs to the workspace; the owner manages assignment, export, delete, and retention per workspace rules.

**Never silently "merge all local jobs" on login** — that would destroy trust.

---

## 12. Seat-limit implications

With a 5-seat plan:

```
Seat 1: Jón — Owner
Seat 2: Ari — Member
Seat 3: Empty
Seat 4: Empty
Seat 5: Empty
```

If Jón tries to invite a 6th active/pending member:

> You've used all 5 seats. Upgrade to Team 15 or remove a member/invite.

**Recommended rule:** `active members + pending invites <= seat limit`.

So 4 active members + 1 pending invite = **5/5 used**. The owner can **cancel** the invite to free the reserved seat.

---

## 13. The worker uses multiple devices

Ari logs into the native mobile app, mobile web, and desktop web. Still: **Ari = 1 seat.**

A seat is **not a device slot** — it is a **human workspace membership**. Members are human users identified by email, and one user can belong to many workspaces. Do **not** count `Ari's phone` and `Ari's laptop` as two seats; that would be hostile and confusing.

---

## 14. What the owner can / cannot do while Ari is a member

**Owner can:** assign/unassign Ari to jobs, remove Ari from the workspace, manage billing, manage workspace settings, delete the workspace, see synced workspace content, generate reports/PDFs (later), manage subscription/seat plan.

**Owner cannot see:** Ari's local-only jobs, Ari's private device storage, or any job Ari never moved/synced to the workspace. **That boundary must be visible in product copy.**

---

## 15. What Ari can do while he is a member

Ari can: use **Local** mode privately, use **Jón Plumbing** workspace mode, capture/edit **assigned** workspace jobs, view **unassigned** jobs read-only, sync assigned job data, use the dashboard if allowed, and **leave** the workspace if supported.

The backend has `POST /workspaces/{id}/leave`, so a member leaving is already planned/partially present.

---

## 16. The owner removes the worker

At the end of employment or a project, Jón removes Ari via **Team → Ari → Remove from workspace**. Confirmation must be explicit:

> **Remove Ari from Jón Plumbing?**
> Ari will lose access to synced workspace jobs and reports.
> His existing synced captures will stay in the workspace record.
> His local-only jobs on his own device will not be affected.
> [Remove member]

After removal:

```
Seats used: 1 / 5

Members
  Jón — Owner

Removed members
  Ari — Removed
```

Ari's seat is **freed immediately**. (Alternatively Ari simply disappears from active members, with an audit log later.)

---

## 17. What happens to Ari's synced work after removal

**Key product/legal/business decision — recommended rule: workspace data stays with the workspace.**

If Ari took photos on "Smith Bathroom Remodel" while a member, those records **remain in Jón Plumbing** after removal. The work was captured under the company workspace, likely for company/client records — removing the worker removes **access**, not job history.

| Thing | Outcome |
| --- | --- |
| Ari's workspace captures | Stay in workspace |
| Ari's access | Revoked |
| Ari's local-only private jobs | Untouched |
| Ari's cached workspace data on device | Becomes inaccessible / purged per sync policy |

The owner still sees attribution:

```
Smith Bathroom Remodel
  Photo by Ari
  Captured June 12, 2026
```

Later you may display `Ari — Former member`. **Do not rewrite history to "Unknown user"** unless required for privacy/legal deletion flows.

---

## 18. What Ari sees after removal

Next time Ari opens the app:

> You no longer have access to Jón Plumbing.
> Workspace data has been removed from this device.
> Your local jobs are still available.

His context switcher now shows only **Local** (not Local + Jón Plumbing). **Removal from a workspace must not lock him out of the app entirely** — local mode stays free.

If he was **offline** when removed, the app may still have cached workspace data. Recommended behavior:

1. Mark the workspace as **"access check required."**
2. **Block new writes.**
3. On next successful sync/session refresh, remove workspace access and **purge/lock** cached workspace data per security policy.

This is enforced **server-side** (read-only / lapse / access enforcement concepts already exist), not just in the UI.

---

## 19. What happens to Ari's local jobs after removal

**Nothing.** Ari's local mode stays intact:

```
Local jobs:
  - Ari private job 1
  - Ari old job 2
  - Ari test photos
```

Jón never gets them unless Ari explicitly moved them into Jón Plumbing earlier. **That is the core trust model.**

---

## 20. If Ari had moved a local job into the workspace

If Ari moved "Smith Bathroom Old Notes" into Jón Plumbing **before** removal, that workspace copy belongs to Jón Plumbing. After removal:

- Jón still sees it in Jón Plumbing.
- Ari no longer sees the workspace copy.
- Ari may or may not still have a local original, depending on implementation.

Two implementation options:

- **Option A (safer UX):** "Move to workspace" = **copy**; the local original remains unless the user deletes it.
- **Option B (stricter data model):** "Move to workspace" = **promote**; the job now belongs to the workspace.

The current design says **one-way promotion** (closer to Option B). From a trust perspective, phrase it carefully and implement as **"copy, then mark as linked/moved" only after sync succeeds**.

---

## 21. Billing implication after removal

Once Ari is removed:

```
Crew 5
Seats used: 1 / 5
Available:  4
```

The plan does **not** auto-downgrade — it just frees a seat. To reduce cost, the owner must downgrade (`crew_5` → `solo_1` or other) at billing renewal. Billing is through **Paddle**, so this happens via the hosted customer portal / billing screen.

---

## 22. Full lifecycle in one flow

```
1. Ari uses app locally
   - No account, no upload, no seat, no owner visibility

2. Jón has Crew 5 workspace
   - Jón counts as 1 seat; 4 seats available

3. Jón invites Ari by email
   - Pending invite reserves 1 seat → Seats: 2/5

4. Ari accepts invite
   - Signs in, joins Jón Plumbing, becomes Member, seat becomes active

5. Ari's app now has: Local context + Jón Plumbing workspace context

6. Ari's old local jobs remain private
   - Not visible to Jón, not synced, not moved unless Ari chooses

7. Jón assigns Ari to jobs
   - Assigned jobs: editable; unassigned jobs: read-only

8. Ari captures records on assigned jobs
   - Photos/notes/voice/files sync to workspace; owner sees them

9. Project ends / worker leaves
   - Jón removes Ari from workspace

10. Ari loses workspace access
   - Seat freed; workspace captures remain with Jón Plumbing;
     Ari's local-only jobs remain on Ari's phone
```

---

## 23. Worker employed by two companies (multi-workspace membership)

A worker has **one personal account** but can belong to **multiple separate workspaces**.

```
Worker: Ari

Contexts in app:
  - Local
  - Jón Plumbing
  - Reykjavík Renovations
```

One user can belong to many workspaces, and the mobile app always shows a context switcher with **Local plus every workspace** the user belongs to.

### 23.1 Seat implication

Ari consumes **one seat in each company workspace**:

```
Jón Plumbing — Crew 5            Reykjavík Renovations — Crew 5
  Jón owner = 1 seat               Owner    = 1 seat
  Ari       = 1 seat               Ari      = 1 seat
  Used: 2 / 5                      Used: 2 / 5
```

He is **not** "one global paid user." The **billing unit is the workspace/company**, not the person's app install. A subscription covers that company's crew, and the owner counts toward that company's seat limit.

### 23.2 What Ari sees — obvious workspace selector

```
Current context: Local

Switch to:
  - Local
  - Jón Plumbing
  - Reykjavík Renovations
```

Selecting **Jón Plumbing** shows only Jón Plumbing jobs. Selecting **Reykjavík Renovations** shows only its jobs. Selecting **Local** shows only private, unsynced local jobs.

The clean mental model:

```
Local     = mine, private, on this device
Company A = data owned by Company A
Company B = data owned by Company B
The two companies do not see each other.
```

**Jón Plumbing cannot see** that Ari also works for Reykjavík Renovations (unless Ari tells them), nor Reykjavík's jobs/photos/notes, nor Ari's local jobs. **Reykjavík Renovations cannot see Jón Plumbing data.** Each workspace is **isolated** — workspace isolation and privacy are part of the Phase 2 sync design.

### 23.3 Assigned jobs stay inside their workspace

```
Jón Plumbing                       Reykjavík Renovations
  - Smith Bathroom — assigned        - Hafnarfjörður Kitchen — assigned
  - Hotel Boiler Room — assigned     - Garage Remodel — read-only
```

Inside Jón Plumbing, Ari can add records only to Jón Plumbing jobs he may edit. Inside Reykjavík Renovations, only to Reykjavík jobs he may edit. MVP rule: **Owner and Member only**; members capture/edit on assigned jobs; owners manage billing, team, and workspace settings.

### 23.4 The app must prevent accidental cross-company capture

This is the **big UX risk.** If Ari takes 20 photos while accidentally in the wrong workspace, that is a serious data leak. So the **active workspace must be extremely visible** — not hidden in settings:

```
Jón Plumbing
Smith Bathroom Remodel

[Photo] [Note] [Voice] [File]
```

Show the workspace name in the **job list header, capture screen, item save screen, upload/sync status, and report/export flow**. For example on save:

```
Save to:
  Jón Plumbing → Smith Bathroom Remodel
```

This prevents "I thought I was saving this to my own company" mistakes.

### 23.5 Can Ari move jobs between the two companies?

**For MVP: No.** Cross-workspace moves are **post-MVP**.

```
Allowed:                          Not allowed in MVP:
  Local → Jón Plumbing              Jón Plumbing → Reykjavík Renovations
  Local → Reykjavík Renovations     Reykjavík Renovations → Jón Plumbing
  (with explicit confirmation)
```

Cross-company movement creates ownership, privacy, and permission problems.

### 23.6 If Ari captures something under the wrong workspace

- **Not synced yet:** allow Ari to discard it locally before sync.
  > This item is queued for upload to Jón Plumbing.
  > [Cancel upload] [Delete item]
- **Already synced:** do **not** allow moving it to the other company. He can delete it only if his permissions allow; otherwise the owner handles it. Once content enters a workspace it belongs to that workspace's record system, and moving it elsewhere could leak data.

### 23.7 What each owner sees

Each owner sees Ari **only inside their own workspace**:

```
Jón Plumbing                       Reykjavík Renovations
  Jón — Owner                        Owner — Owner
  Ari — Member                       Ari — Member
  Seats used: 2 / 5                  Seats used: 2 / 5
```

Neither owner gets a **global profile** of Ari's other memberships. At most:

```
Ari
  Role: Member
  Assigned jobs in this workspace: 2
  Last active in this workspace: Today
```

`Last active` should be **workspace-specific**, not global.

### 23.8 If one company removes Ari

If Jón Plumbing removes Ari:

```
Local                  — still available
Jón Plumbing           — removed
Reykjavík Renovations  — still available
```

Ari loses access only to Jón Plumbing. He keeps his local jobs, his Reykjavík Renovations access, and the same login account. Jón Plumbing's synced records created by Ari remain in Jón Plumbing; Reykjavík Renovations is unaffected.

### 23.9 If Ari deletes his account

A separate, more serious flow than "remove worker from company." It requires a policy: remove Ari's login/session, remove active memberships, **keep company-owned workspace records**, and anonymize or preserve attribution per legal/privacy policy. Normal "remove worker from company" is **not** the same as deleting Ari's global user account.

### 23.10 Recommended product rule (multi-workspace)

- A user account can belong to **many workspaces**.
- A seat is consumed **per workspace membership**.
- Data belongs to **the context where it was created**.
- **No cross-workspace visibility.**
- **No cross-workspace moves in MVP.**
- **Local data stays private** unless explicitly promoted.

That gives the cleanest UX and the least dangerous privacy model.

---

## 24. Implementation milestones

This section turns the narrative above into an ordered, surface-by-surface delivery plan. Milestones are labelled **SM1–SM9** (Seat/Membership) so they don't collide with the web dashboard's `M0–M9` milestones. Each one lists what **already exists**, what to **add**, and the lifecycle sections it closes.

Status legend per task: **[have]** already in repo · **[partial]** exists but incomplete · **[add]** not started.

### Where we are today (baseline)

The plumbing is far more complete than the UX. A quick read of the current state:

| Surface | Solid today | Largest gaps |
| --- | --- | --- |
| **API** (`services/api/`) | Workspace + membership schema, roles, auto-create on signup/OAuth, `GET /workspaces` with access metadata, **invite CRUD + accept**, **pending invites reserve seats**, plan→seat-limit map (`solo_1`/`crew_5`/`team_15`), seat-limit enforced on invite, `job_assignments` table + `GET /assignments`, **read-only 403** for unassigned members + lapsed subscription, leave + remove-member, Paddle webhooks/portal/trial/grace. | **No assign/unassign endpoints** (`revoked_at` never written), no workspace update/branding, **no local→workspace promotion**, **no account deletion / owner transfer**, downgrade not enforced on webhook, no membership-revocation cleanup, no session/membership re-check signal. |
| **Web** (`web/`) | Team page (members + invites + roles), invite/resend/cancel/remove, Paddle checkout + portal, trial/grace/read-only banners, **read-only job detail** for unassigned members, full auth except Apple. | **No job-assignment UI**, **workspace switcher is a non-functional stub** (`workspaces[0]` only), thin member detail (no status/assigned-count/seat), **invite-accept drops token for signed-out users**, seat copy says "Members" not "Seats used", no downgrade guard, no Leave-workspace action. |
| **Mobile** (`app/`) | Local-first capture with no account gate, **Local + workspace context switcher**, email/password + signup + Google (Android), `SyncScheduler`, **assigned-jobs-only pull**, subscription read-only push-skip + paused banner. | **No invite/deep-link/magic-link accept**, **no move-to-workspace**, no assigned/unassigned sections, **no UI write-guards** before the 403, **no removal purge / access-check / messaging**, no workspace label on capture/save screens, no periodic `/me` refresh, no Apple / iOS-Google / magic link. |

> Guiding sequence: make the **seat math and invite→accept loop airtight** first (SM1–SM2), then ship the **assignment system** that the whole Member experience depends on (SM3–SM4), then the **mobile join + local/workspace boundary** (SM5–SM6), then **removal + billing lifecycle** (SM7–SM8), and finally **account deletion** (SM9).

---

### SM1 — Seat math & invite→accept loop, airtight

**Goal:** Every seat count shown anywhere is correct, and an invited worker can always complete sign-in → accept → become a member, including when signed out or without an account. Closes the integrity gaps in §3–§7, §12.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | Keep `active + pending ≤ limit` on **create**; also re-validate on **accept** and treat expired pending invites as freed. Add explicit `expired` transition (cron or lazy on read). | [partial] |
| 2 | API | Apply `requireWorkspaceWritable` to **resend** and **revoke** invites (today only create checks it). | [partial] |
| 3 | API | Add `assigned_job_count` + `status` to the `GET /workspaces/{id}/team` member rows; update `last_active_at` on real activity, not just leave/remove. | [add] |
| 4 | Web | Fix `middleware.ts` so `/invite/accept` is a public path **and preserves the `token` query param** through `?next=`. | [add] |
| 5 | Web | Point the invite-accept "Create account" link at `/signup?next=…` (currently `/login`). | [partial] |
| 6 | Web | Rename team/billing seat copy to **"Seats used: X / Y"** and add the spec "You've used all N seats — upgrade or remove a member/invite" message at the limit. | [partial] |
| 7 | Web | Render member **status** and **assigned-jobs count** in the team list (data added in task 3). | [add] |

**Acceptance:** Owner invites → `Seats used: 2/5`; cancelling frees the seat; a signed-out invitee clicking the email link lands on the join page, can create an account, and ends up a member without losing the token.

---

### SM2 — Web workspace context switcher (multi-workspace parity)

**Goal:** The web dashboard stops hard-coding `workspaces[0]` and gains the same context model the app already has, so a worker in two companies (§23) can use the dashboard. Closes §23.2 for web.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | Web | Replace the header switcher **stub** in `dashboard-shell.tsx` with a real dropdown listing all `session.workspaces`. | [partial] |
| 2 | Web | Persist the active workspace (cookie/URL param) and thread it through jobs/team/settings/reports instead of `workspaces[0]`. | [add] |
| 3 | Web | Mobile-web: make the `jobs-client` workspace control open the same switcher. | [partial] |
| 4 | API | (Optional) `GET /workspaces/{id}` single-workspace fetch to back deep links into a non-default workspace. | [add] |

**Acceptance:** An owner/member of two workspaces can switch between them on desktop and mobile web; each surface shows only that workspace's jobs/team/billing; refresh and back-button preserve the selection.

---

### SM3 — Job assignment system (API + owner UI)

**Goal:** Owners can actually assign/unassign members to jobs — the missing backbone for the entire Member experience (§7, §8). This is the single biggest gap.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | `POST /workspaces/{id}/jobs/{jobId}/assignments` and `DELETE …/{userId}` (sets/clears `revoked_at`). Owner-only; validates target is an active member. | [add] |
| 2 | API | Owner-facing assignment read model: `GET /workspaces/{id}/assignments` should return the **full matrix** (job ↔ member) for owners, not just the caller's view. | [partial] |
| 3 | Web | Assignment UI on **job detail** (member multi-select) and/or a per-member "Assign jobs" panel, with optimistic update + toast (matches dashboard UX bar). | [add] |
| 4 | Web | Surface assignees on the job list / detail header. | [add] |
| 5 | API | Make reports respect assignment if required (today any member can report on any workspace job). | [partial] |

**Acceptance:** Owner opens a job, assigns Ari; Ari's `GET /assignments` now includes it; owner sees Ari listed as assignee. Unassigning writes `revoked_at` and Ari loses write access on next sync.

---

### SM4 — Member read-only experience (assigned vs unassigned), both clients

**Goal:** Members clearly see "Assigned to me" vs read-only "Other workspace jobs", and the UI blocks writes **before** the server 403. Closes §9 end-to-end.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | Decide member job visibility: either (a) keep assigned-only pull, or (b) return unassigned workspace jobs with `read_only: true`. Spec §9 wants **read-only visibility** of other jobs — implement (b) behind the existing access flags. | [partial] |
| 2 | Mobile | Add `readOnly` to the `Job` model; honor `bundle.read_only` on merge. | [add] |
| 3 | Mobile | Split the job list into **Assigned to me** and **Other workspace jobs — Read-only** sections. | [add] |
| 4 | Mobile | Use the already-present `workspaceWritable()` helper to gate the job-detail FAB, capture, edit, delete, and tagging; show the "Ask the owner to assign you before adding records" copy. | [add] |
| 5 | Web | Add a read-only badge on the **jobs list** (today enforcement only appears after opening a job). | [partial] |
| 6 | Web | Align banner copy with the spec ("Ask the owner to assign you before adding records"). | [partial] |

**Acceptance:** A member sees their two assigned jobs as editable and the rest read-only on both app and web; tapping "add" on a read-only job is blocked client-side, and the server still returns 403 as defense-in-depth.

---

### SM5 — Mobile invite acceptance & join flow

**Goal:** A worker can accept an invite from the phone — the §4–§7 flow that is entirely missing on mobile.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | Mobile | Add deep-link / universal-link handling (`app_links`) + Android intent filters + iOS associated domains for `…/invite/accept?token=`. | [add] |
| 2 | Mobile | "You've been invited to {workspace}" screen → sign in (or create account) → `POST /invites/accept`. | [add] |
| 3 | Mobile | Add **magic-link** sign-in (API supports it; app doesn't) so email invites work one-tap. | [add] |
| 4 | Mobile | After accept, auto-select the new workspace context and kick off a sync. | [partial] |
| 5 | Mobile | Enable **Google on iOS** and add **Sign in with Apple** (also web). | [add] |

**Acceptance:** Ari taps the invite email on his phone, the app opens to the join screen, he signs in with a magic link, becomes a member, and lands in the Jón Plumbing context with assigned jobs syncing — his local jobs untouched.

---

### SM6 — Local↔workspace boundary & one-way promotion

**Goal:** Protect the trust model: local data never auto-uploads, promotion is explicit and one-way, and capture can't go to the wrong company. Closes §6, §11, §23.4–§23.6.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | Promotion endpoint that copies a local job's payload into a workspace (job + items + media), idempotent, owner/member-writable. **Copy-then-mark-linked after sync succeeds** (Option A wording in §20). | [add] |
| 2 | Mobile | "Move to workspace" action with the §11 warning copy; promote only after a successful sync; keep the local original per Option A. | [add] |
| 3 | Mobile | Show the **active workspace name** on capture hub, each capture screen, and the save/batch-review screen (the §23.4 anti-leak requirement). | [add] |
| 4 | Mobile | Route guards on `/jobs/:id` + `/jobs/:id/capture/*` so a job from another context can't be opened/captured into by direct navigation. | [add] |
| 5 | Mobile | "Cancel upload / delete item" affordance for not-yet-synced items captured in the wrong context. | [add] |

**Acceptance:** Joining a workspace shows two contexts and uploads nothing automatically; "Move to workspace" copies a chosen local job after explicit confirmation; the workspace name is always visible while capturing; cross-workspace job moves are not offered.

---

### SM7 — Member removal & access revocation

**Goal:** Removing a member frees the seat, revokes access everywhere, keeps workspace data, and never touches the worker's local jobs. Closes §16–§20, §23.8.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | On remove/leave, **revoke that user's `job_assignments`** (`revoked_at`) and keep their captured records attributed (don't reassign/delete). | [partial] |
| 2 | API | Provide a cheap **membership/access signal** the clients can poll (e.g. include membership status in `/me` and the workspace cursor) so removal is detected server-side, not just in UI. | [add] |
| 3 | Mobile | Periodic `/me` refresh while the app is open; detect a removed workspace. | [add] |
| 4 | Mobile | On removal: mark workspace **"access check required"**, **block new writes**, then **purge/lock cached workspace data** (wire up the existing-but-unused `purgeAfterSync`); reset `captureContext` off the removed workspace. | [add] |
| 5 | Mobile | Post-removal messaging: "You no longer have access to {workspace}… Your local jobs are still available." | [add] |
| 6 | Web | Richer member detail (status, assigned-jobs count, **Seat: Occupied**, last active in this workspace) and the §16 removal confirmation copy. | [partial] |
| 7 | Web/API | After removal show `Seats used: 1/5` and optionally a "Former member" attribution rather than rewriting history. | [partial] |

**Acceptance:** Owner removes Ari → seat frees immediately, Ari's synced captures stay in the workspace (attributed), Ari's app drops the workspace context and purges its cache on next refresh, and Ari's local jobs are untouched.

---

### SM8 — Billing & seat lifecycle completeness

**Goal:** Plan ↔ seat changes are safe and legible end-to-end. Closes §12, §21.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | Enforce `CanDowngradeTo` on the **webhook** `subscription.updated`, not just the portal preflight, so Paddle downgrades can't push a workspace over its seat limit. | [partial] |
| 2 | Web | Downgrade guard UI: "Remove N members/invites before downgrading"; wire the existing `target_plan_sku` portal path. | [partial] |
| 3 | Web | "All seats used" upgrade prompt at the invite limit (links to plan change). | [partial] |
| 4 | API | Enforce `sync_push_allowed` on mutation handlers (currently computed/returned but only `writable` is checked). | [partial] |
| 5 | Web/API | Confirm a freed seat (after removal) immediately reflects in billing + team counts. | [partial] |

**Acceptance:** Owner with 4 members can't downgrade `crew_5 → solo_1` until they remove members; the UI explains why; removing a member frees a seat that's reflected on the billing screen.

---

### SM9 — Account deletion (separate, careful flow)

**Goal:** Deleting a *user account* is distinct from being removed from a company. Closes §23.9.

| # | Surface | Task | Status |
| --- | --- | --- | --- |
| 1 | API | `DELETE /auth/me`: revoke sessions, end active memberships, **keep workspace-owned records**, anonymize or preserve attribution per policy. | [add] |
| 2 | API | Owner can't orphan a workspace: require **transfer ownership** or **delete workspace** before owner-account deletion. | [add] |
| 3 | Web/Mobile | Account-deletion entry point with explicit, irreversible-action confirmation; "Leave workspace" action surfaced in account settings (web + mobile). | [add] |

**Acceptance:** A worker can delete their account; company records they captured remain in each workspace; an owner is forced to transfer or delete the workspace first.

---

### Dependency / sequencing summary

```
SM1 (seat math + invite loop)  ──► SM2 (web switcher)
        │                              │
        └──────────► SM3 (assignment API + owner UI)
                          │
                          ▼
                     SM4 (member read-only UX, both clients)
                          │
        ┌─────────────────┼───────────────────┐
        ▼                 ▼                   ▼
   SM5 (mobile join)  SM6 (local↔ws boundary)  SM7 (removal/revocation)
                                              │
                                              ▼
                                         SM8 (billing/seat lifecycle)
                                              │
                                              ▼
                                         SM9 (account deletion)
```

**Suggested cut for a first usable team release:** SM1 → SM3 → SM4 → SM5 give the complete invite → assign → capture → sync loop on both clients. SM6–SM9 harden privacy, removal, and billing.
