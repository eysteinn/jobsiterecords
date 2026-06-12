# Job timeline photo layout — implementation plan

**Status:** Done (Phase 1 + Phase 1b implemented 2026-06-04)  
**Created:** 2026-06-04  
**Scope:** Web dashboard job detail (`/jobs/:id`)  
**Related docs:** [`web-dashboard-design.md`](web-dashboard-design.md) §4.2, [`high-level-design.md`](high-level-design.md) §6.3

**Positioning:** Borrow layout patterns that work (dense photo grid, day groups, lightbox). Job Site Records stays a **unified job record** for trades + office — not a photo-PM clone.

---

## 0. Audience (design north star)

| Who | Where | Job on this screen |
| --- | --- | --- |
| **Field tradesperson** | Phone (capture); occasionally web | Rarely lives here — capture is mobile. When they open web, they need to **recognize their shots** quickly and fix a wrong caption. |
| **Office manager / lead** | Desktop (primary web user) | **Scan 50–200 items** from today’s crew: did we document the pour, the leak, the change order? **Play voice notes**, read notes, **open photos full size**, fix captions before zip/PDF handoff. |

**Shared traits:** Busy, gloved or multitasking, low patience for UI chrome. They think in **“what happened on the job that day?”** not in albums or folders.

### UX principles (non-negotiable)

1. **Chronological story** — Time order within each day is sacred (photos + voice + notes interleaved). Managers reconstruct events; splitting “Photos only” breaks that.
2. **Glanceable photos** — Many thumbs per screen; recognizable content (crop is OK; illegible is not).
3. **Obvious affordances** — Photo = click to enlarge. Voice = play in place. File = download link. Note = read text. No mystery icons.
4. **Plain language** — “Photo”, “Voice”, “Note”, “File” (already used). Not “asset”, “media item”, “entry”.
5. **Big click targets** — Entire photo cell opens lightbox; row min height ≥ 48px for non-photo items.
6. **Caption when it matters** — Short line under photo thumb; full edit in lightbox (manager workflow). Don’t force edit on grid click.
7. **Respect office workflow** — “Add text note” stays at top; timeline below. Managers add context from the desk.
8. **What works elsewhere** — Camera roll / Google Photos grid for **browse**; messaging-app row for **mixed feed** (voice/note). Combine both: grid for photo runs, rows for everything else.

---

## 1. Problem

Web job detail uses **one full-width card per item** with photos capped at **280px** left-aligned → huge empty bands on portrait shots, heavy scroll for managers reviewing a day’s work.

| Piece | Location |
| --- | --- |
| Timeline | `web/components/job-detail-client.tsx` (lines ~127–147) |
| Styles | `web/components/job-detail.module.css` (`.item`, `.thumb`) |
| Sort | API `ORDER BY captured_at DESC` — keep |

---

## 2. What we borrow vs what stays Job Site Records

| Borrow (proven) | Job Site Records-only |
| --- | --- |
| Responsive **photo grid** under date headings | **One timeline** — photos, voice, notes, files **interleaved** |
| Click thumb → **lightbox** | Handoff = zip / PDF later, not live client photo feed |
| Day headers + newest-first | Mobile parity on grouping; web grid only for photos |

Do **not** add: separate Photos tab, company-wide photo feed, bulk Actions bar, or CC-style share links in this initiative.

---

## 3. Resolved product decisions

| # | Decision | Rationale (audience) |
| --- | --- | --- |
| D1 | **Interleaved** segments per day | Manager sees “photo → voice memo → more photos” in capture order |
| D2 | **Square grid cells**, `object-fit: cover` | Maximum thumbs per screen; full image in lightbox |
| D3 | **Time on photo** — bottom-right overlay on thumb | Scan “when” without opening; high contrast pill |
| D4 | **Caption** — one truncated line under thumb; **edit in lightbox only** for Phase 1 | Avoid accidental edit on browse; grid stays tap = enlarge |
| D5 | **Non-photo = horizontal row** (72px icon column + text) | Matches mobile mental model; voice player visible |
| D6 | **Thumb width `w=384`** in grid (not 512) | Balance clarity and bandwidth for many cells |
| D7 | **Grid columns** — see §4 breakpoints | ~4–6 photos across on typical office monitor |
| D8 | **Lightbox 1b** — prev/next all **photo** items in job, keyboard + buttons | Manager flips through today’s shots without closing |
| D9 | **No tags on grid in Phase 1** | Tags on web timeline not shipped; don’t fake chips |

---

## 4. Visual & interaction spec

### 4.1 Day block

```
┌─ Wednesday, June 4, 2026 ─────────────────────────────┐
│  [photo][photo][photo][photo]   ← grid segment         │
│  ┌──────────────────────────────────────────────┐   │
│  │ ▶ 2:15 PM · Voice · "Leak under sink…"       │   │  ← row
│  └──────────────────────────────────────────────┘   │
│  [photo][photo]                                        │
│  ┌──────────────────────────────────────────────┐   │
│  │ 1:02 PM · Note · Body preview…                │   │
│  └──────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

- Date `h3`: unchanged (`0.875rem`, muted).
- Segment gap: `12px` between grid and rows, `10px` between rows.

### 4.2 Photo grid (`PhotoGrid` / `PhotoCell`)

| Property | Value |
| --- | --- |
| Layout | `display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 10px;` |
| Cell | `aspect-ratio: 1`; thumb fills cell, `border-radius: 8px`, `border: 1px solid var(--border)` |
| Hover | Subtle `outline` or `box-shadow` — signals clickable |
| Time overlay | `position: absolute; bottom: 6px; right: 6px;` — `font-size: 11px`, white text on `rgba(0,0,0,.65)` pill, `padding: 2px 6px`, `border-radius: 4px` |
| Caption | Below thumb (outside square): `font-size: 12px`, `color: var(--muted)`, `max 2 lines` ellipsis; empty → `No caption` in lighter style (not a button in Phase 1) |
| Pending | Gray cell, centered “Uploading…” — same copy as today |
| `aria-label` | `"Photo, {time}, {caption or no caption}"` |

**Breakpoints (min column width):**

| Viewport | `minmax` | ~columns @ 1200px content |
| --- | --- | --- |
| ≥ 1024px | `160px` | 5–6 |
| 768–1023px | `140px` | 4–5 |
| &lt; 768px | `120px` | 2–3 (MVP: acceptable per design doc) |

### 4.3 Non-photo row (`TimelineRow`)

Mirror mobile `_ItemRow` (72×72 left column on web for slightly easier tap):

| Kind | Left column | Right column |
| --- | --- | --- |
| **voice** | Mic icon in gray box (or small waveform placeholder) | `time` **bold** + `Voice` label; `<audio controls>` full width of right column; caption/preview 1 line if `item.caption` |
| **note** | Sticky-note icon | `time` + `Note`; `item.body` up to 2 lines; optional caption line |
| **file** | PDF/file icon | `time` + `File`; download link (existing `ItemMedia` behavior) |

- Card: same `.timelineRow` surface as current `.item` (white, border, `padding: 12px`, `border-radius: var(--radius)`).
- **Do not** open lightbox for non-photo rows in Phase 1.
- Voice: **must** show native `<audio controls>` — manager listens without extra clicks.

### 4.4 Lightbox (Phase 1 — keep; Phase 1b — extend)

**Phase 1 (with grid):** unchanged behavior — click cell → overlay, full image, × close.

**Phase 1b additions:**

| Element | Spec |
| --- | --- |
| Prev / Next | Chevron buttons overlaid left/right; also `ArrowLeft` / `ArrowRight` keys |
| Scope | All items where `kind === 'photo'` in job, order = same as timeline (`captured_at DESC`) |
| Caption | `InlineCaption` or textarea **below** image inside lightbox; save uses existing `saveCaption` |
| Meta line | `{date} · {time}` under caption |
| Focus | Trap focus in lightbox; `Escape` closes |

---

## 5. Code structure

### 5.1 Files (Phase 1)

| File | Action |
| --- | --- |
| `web/components/job-detail-client.tsx` | Refactor timeline rendering; add helpers + subcomponents |
| `web/components/job-detail.module.css` | Add grid/row/lightbox-1b classes; stop using `.item`/`.thumb` for photos |

Optional later: extract `web/components/job-timeline/` if file grows past ~350 lines.

### 5.2 Types & helpers (add to `job-detail-client.tsx`)

```ts
type TimelineSegment =
  | { type: "photos"; items: Item[] }
  | { type: "row"; item: Item };

/** Items for one day, newest first (API order). */
function segmentDayItems(dayItems: Item[]): TimelineSegment[] {
  const segments: TimelineSegment[] = [];
  let photoBatch: Item[] = [];

  const flush = () => {
    if (photoBatch.length > 0) {
      segments.push({ type: "photos", items: photoBatch });
      photoBatch = [];
    }
  };

  for (const item of dayItems) {
    if (item.kind === "photo") {
      photoBatch.push(item);
    } else {
      flush();
      segments.push({ type: "row", item });
    }
  }
  flush();
  return segments;
}

function photoItemsInJob(items: Item[]): Item[] {
  return items.filter((i) => i.kind === "photo");
}
```

### 5.3 Component tree

```
JobDetailClient
├── PageShell, compose (unchanged)
└── dayGroup × N
    ├── h3 date
    └── div.dayContent
        └── segment × M
            ├── PhotoGrid → PhotoCell × k
            └── TimelineRow (ul.timelineRows > li)
```

**Markup choice:** Drop outer `<ul className={styles.timeline}>` per day. Use `div.dayContent` with segments — grids are not list items. Rows live in `<ul className={styles.timelineRows}>` for semantics.

### 5.4 `PhotoCell` props

```ts
type PhotoCellProps = {
  item: Item;
  media: MediaFile[];
  onOpen: (itemId: string, mediaId?: string) => void;
};
```

- Renders `button.photoCell` → `img` (`/api/items/${id}/thumb?w=384`) + time overlay.
- Caption: read-only `<p className={styles.photoCaption}>` (truncate).
- Pending: `div.photoCellPending` if no uploaded `primary_photo`.

### 5.5 `TimelineRow` props

```ts
type TimelineRowProps = {
  item: Item;
  media: MediaFile[];
  onSaveCaption?: (item: Item, caption: string) => Promise<void>; // notes only if caption used
};
```

- Reuse `ItemMedia` for voice/file/audio.
- For **note**: show `item.body`; hide `InlineCaption` on grid/row for Phase 1 (notes editable later on item detail if needed — out of scope unless already required).

### 5.6 Replace day render loop

**Before:**

```tsx
<ul className={styles.timeline}>
  {dayItems.map((item) => (
    <li className={styles.item}>...</li>
  ))}
</ul>
```

**After:**

```tsx
<div className={styles.dayContent}>
  {segmentDayItems(dayItems).map((seg, i) =>
    seg.type === "photos" ? (
      <PhotoGrid key={`g-${i}`} items={seg.items} mediaByItem={mediaByItem} onOpenPhoto={...} />
    ) : (
      <ul key={`r-${seg.item.id}`} className={styles.timelineRows}>
        <li>
          <TimelineRow item={seg.item} media={...} />
        </li>
      </ul>
    )
  )}
</div>
```

Coalesce adjacent `timelineRows` into one `<ul>` per contiguous row segments (optional polish): merge segments in a second pass or render rows in one ul between grids — implementer can use simple “one ul per row segment” for v1.

---

## 6. CSS additions (concrete)

Add to `job-detail.module.css`:

| Class | Purpose |
| --- | --- |
| `.dayContent` | `display: flex; flex-direction: column; gap: 12px;` |
| `.photoGrid` | Grid per §4.2 |
| `.photoCell` | `position: relative; display: flex; flex-direction: column; gap: 4px; border: none; padding: 0; background: none; cursor: pointer; text-align: left;` |
| `.photoThumbWrap` | `position: relative; aspect-ratio: 1; border-radius: 8px; overflow: hidden;` |
| `.photoThumb` | `width: 100%; height: 100%; object-fit: cover; display: block;` |
| `.photoTime` | Overlay pill per §4.2 |
| `.photoCaption` | Muted 2-line clamp |
| `.photoCellPending` | Muted centered square |
| `.timelineRows` | `list-style: none; margin: 0; padding: 0; display: grid; gap: 8px;` |
| `.timelineRow` | Replaces `.item` for non-photo |
| `.timelineRowMain` | `display: flex; gap: 12px; align-items: flex-start;` |
| `.timelineRowIcon` | `width: 72px; height: 72px; flex-shrink: 0; …` |
| `.timelineRowBody` | `flex: 1; min-width: 0;` |
| `.timelineRowMeta` | Time + kind line (reuse `.itemMeta` styles) |

**Remove / deprecate for photos:** `.thumbBtn`, `.thumb` max-width layout on photo path only.

**Lightbox 1b classes:** `.lightboxNav`, `.lightboxNavPrev`, `.lightboxNavNext`, `.lightboxCaption`.

---

## 7. Implementation checklist

### Phase 1 — Photo grid + rows (~1 PR)

- [x] **1.** Add `segmentDayItems`, `TimelineSegment` in `job-detail-client.tsx`
- [x] **2.** Implement `PhotoCell` + `PhotoGrid` per §5.4–5.5
- [x] **3.** Implement `TimelineRow` per §4.3 (`RowMedia` for voice/file)
- [x] **4.** Wire `dayContent` / segment loop; remove per-photo `.item` cards
- [x] **5.** Add CSS §6; verify hover/focus visible on photo cells
- [ ] **6.** Manual test §8 (on deploy / local)
- [x] **7.** Update `web-dashboard-design.md` §4.2 (photo grid + compact rows)
- [x] **8.** Update `high-level-design.md` implementation status if needed
- [x] **9.** Set plan header **Status: Done (Phase 1)**

### Phase 1b — Lightbox navigation (~1 small PR)

- [x] **1.** `photoItemsInJob(items)` + index from `lightbox.itemId`
- [x] **2.** Prev/next handlers + keyboard listener (`useEffect`)
- [x] **3.** UI buttons + caption block in lightbox per §4.4
- [ ] **4.** Manual test: 10 photos, keyboard only, caption save
- [x] **5.** Doc: lightbox prev/next in `web-dashboard-design.md`

### Phase 2 (separate initiative)

Tags on thumbs, bulk select, filters — only when API/UI exist per `web-dashboard-design.md` §4.2.

---

## 8. Test plan

| # | Scenario | Pass |
| --- | --- | --- |
| T1 | 24 portrait photos, 1280px wide | ≥ 4 columns; no large white gutters |
| T2 | Mixed: 5 photos AM, voice, 3 photos PM same day | Voice row **between** photo groups |
| T3 | Manager plays voice from row | Audio plays without opening lightbox |
| T4 | Click photo | Lightbox full image |
| T5 | Photo pending upload | Gray cell, message visible |
| T6 | Note with long body | 2-line clamp; row readable |
| T7 | Add text note form | Still works; new note appears in correct day |
| T8 | 768px width | 2–3 columns; no horizontal scroll |
| T9 | Keyboard Tab | Photo cells focusable; visible focus ring |
| T10 (1b) | Arrow keys | Moves between photos only, wraps or stops at ends (document choice: **stop at ends**) |

---

## 9. Out of scope (this initiative)

- Client share links, bulk Actions bar, tags on grid, filters, two-column job header
- Mobile Flutter grid (mobile list is already dense)
- Caption edit on grid click (Phase 1 — lightbox only in 1b)
- Item detail page on web

---

## 10. Success metrics

- Manager can scan **≥ 2× photos per viewport** vs current cards (target 4× on wide screens).
- Mixed-day story readable without scrolling past empty card whitespace.
- Zero regression on voice playback and note display.

---

## 11. Reference links (optional)

- [CompanyCam galleries/timelines](https://companycam.com/features/galleries-timelines) — reference only; see §2.
