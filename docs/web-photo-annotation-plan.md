# Web photo annotation — implementation plan

**Status:** Implemented (2026-06-05)  
**Goal:** Full **functional parity** with mobile photo mark-up ([§6.4a](high-level-design.md#64a-photo-annotation-mark-up)) in the web dashboard.  
**Depends on:** Display-only work already shipped (annotated render in grid/lightbox, hold-to-peek original).  
**Related:** [`web-dashboard-design.md`](web-dashboard-design.md) §4.2, [`job-timeline-photo-grid-plan.md`](job-timeline-photo-grid-plan.md), mobile code in `app/lib/features/photo_annotation/` and `app/lib/domain/services/photo_annotation_renderer.dart`.

---

## 1. Parity checklist (mobile → web)

| Capability | Mobile | Web today | Required for parity |
| --- | --- | --- | --- |
| Show annotated render in timeline | ✓ | ✓ | — |
| Hold / peek original | ✓ | ✓ | — |
| **Annotate** entry on saved photo | Item Detail + batch review | — | Lightbox **Annotate** button (+ URL `?item=&annotate=1`) |
| Tools: pen, line, arrow, circle, rectangle, text | ✓ | — | Same six tools |
| Color palette (5 swatches) | ✓ | — | `#EF4444`, `#EAB308`, `#FFFFFF`, `#111827`, `#22C55E` |
| Undo / redo (per stroke) | ✓ (50-deep stack) | — | Same |
| Clear all + confirm | ✓ | — | Same |
| Discard unsaved + confirm | ✓ | — | Same on close / `Esc` |
| Text label dialog (max 80 chars) | ✓ | — | Same |
| Load existing strokes as editable | ✓ (overlay JSON) | — | Requires overlay on server (see §3) |
| Save: overlay JSON + flattened JPEG | ✓ | — | Client render + upload |
| Save empty: remove annotation media | ✓ | — | Delete overlay + render rows |
| Original photo never overwritten | ✓ | — | Server keeps `primary_photo`; render is separate |
| Edit gated by job assignment | N/A (local) | partial | Respect `read_only` on job bundle |

**Out of scope (same as mobile):** blur/redact, crop, rotate, filters, measurement, batch-review annotate before first save (web has no capture flow).

**Product note — capture vs upload vs mark-up:**

| Term | Meaning | Web MVP |
| --- | --- | --- |
| **Capture** | Live camera / mic workflow (multi-shot, voice record) | **No** — mobile app |
| **Upload** | Pick existing files from disk (photos, PDFs) | **Future** milestone (not MVP) |
| **Mark-up** | Annotate an existing timeline photo | **Yes** — this plan |

[`web-dashboard-design.md`](web-dashboard-design.md) “no in-browser photo capture” refers only to **capture**; it does **not** rule out later **upload** or current **annotation** of synced photos.

---

## 2. Mobile reference (authoritative behaviour)

### 2.1 Overlay JSON (document version 2)

Stored at `photo.annotations.json`. Coordinates are **normalized 0–1** relative to the image pixel dimensions (not the letterboxed canvas).

```json
{
  "version": 2,
  "shapes": [
    { "type": "arrow", "color": "#EF4444", "p1": [0.1, 0.2], "p2": [0.8, 0.7] },
    { "type": "pen", "color": "#22C55E", "points": [[0.2, 0.3], [0.25, 0.35]] },
    { "type": "ellipse", "color": "#EAB308", "rect": [0.1, 0.1, 0.3, 0.2] },
    { "type": "text", "color": "#111827", "p1": [0.4, 0.6], "text": "Leak here" }
  ]
}
```

Shape types: `pen`, `line`, `arrow`, `ellipse`, `rectangle`, `text`.  
Stroke width: `max(2px, imageWidth × 0.0035)`. Text: `fontSize = max(14, imageWidth × 0.028)`, semi-transparent black background pill.

### 2.2 Save pipeline (mobile)

1. Write overlay JSON to disk.
2. Flatten strokes onto original pixels → `photo.annotated.jpg` (JPEG q≈90).
3. Replace `media_files` rows: delete prior `annotation_overlay` + `annotated_render`, insert new rows.
4. Bump `items.updated_at` (and job) for sync.

Empty document → delete overlay + render files and media rows (revert to original-only display).

### 2.3 Entry UX (mobile)

Full-screen editor: photo canvas + bottom toolbar. App bar: Close (discard confirm), Save. Pen uses drag; text uses tap → dialog.

---

## 3. Blockers — sync & API (must ship first)

These gaps prevent **re-opening editable strokes** on web and break the documented data model.

### 3.1 `annotation_overlay` never reaches the server

Mobile sets `needsBlobUpload = false` for `annotation_overlay` and excludes it from the sync upload query. Only `annotated_render` is pushed. **Web cannot load strokes** for photos annotated on a phone.

**Fix (mobile `app/lib/sync/sync_engine.dart` + `media_file.dart`):**

- Include `annotation_overlay` in pending media upload list.
- Upload with server role `annotation_overlay` (add mapping; stop collapsing to `file`).
- On pull, map server roles `annotation_overlay` and `annotated_render` to local roles (today `_localRole` drops them to `attachment`).

### 3.2 `annotated_render` uploaded as `primary_photo`

`MediaRole.annotatedRender.serverRole` returns `primary_photo`, so the flattened JPEG can **replace** the server’s notion of the original photo. That violates HLD (“original preserved”) and confuses web `getPhotoMedia()` which looks for role `annotated_render`.

**Fix (mobile):**

- `serverRole` for `annotatedRender` → `'annotated_render'`.
- Keep skipping re-upload of raw `primary_photo` when a synced annotated render exists (existing `_shouldUploadMedia` logic).

**Backfill:** Jobs already synced with annotated JPEG as `primary_photo` need a one-time migration or re-sync script (detect duplicate `primary_photo` rows / missing original — product decision).

### 3.3 API mime allowlist

`application/json` is not in `services/api/internal/jobs/mime.go`. Overlay upload will fail.

**Fix:** Add `application/json` to allowed types; skip magic-byte validation for JSON (or validate `{` prefix).

### 3.4 No media delete endpoint

Saving annotations **replaces** overlay + render rows. Clearing annotations **deletes** them. API has `deleted_at` on `media_files` but no handler.

**Fix:** `DELETE /api/v1/media-files/{mediaID}` (soft-delete) or `POST .../delete` — same auth/read_only checks as create. Web BFF proxy under `/api/media/[mediaId]`.

### 3.5 Web BFF lacks upload routes

Mobile calls API directly; web needs cookie-auth proxies:

| Route | Proxies to |
| --- | --- |
| `POST /api/items/[itemId]/media-files` | CreateMedia (mint presigned PUT) |
| `POST /api/media/[mediaId]/complete` | CompleteMedia |
| `DELETE /api/media/[mediaId]` | new soft-delete |

Browser PUTs JSON/JPEG bytes to presigned MinIO URL (same as mobile).

### 3.6 Thumbnail cache after save

Thumbs are cached in object storage at `{storageKey}/thumb-{w}.jpg`. After annotation save, invalidate or bump cache key (e.g. include `updated_at` in cache path, or delete cached thumb on complete for annotated render).

### 3.7 `read_only` not wired in web UI

`JobBundle.read_only` exists but `JobDetailClient` ignores it. Hide **Annotate**, caption edit, and note compose when read-only; show existing banner from web-dashboard spec.

---

## 4. Web architecture

### 4.1 Shared TypeScript module

Port mobile logic to `web/lib/photo-annotation/` (no React):

| File | Purpose |
| --- | --- |
| `types.ts` | `PhotoAnnotationDocument`, `PhotoAnnotationShape`, `AnnotationTool`, palette |
| `layout.ts` | `ImageLayoutMetrics` — letterbox `contain`, norm ↔ display |
| `renderer.ts` | `paintShapes(ctx, shapes, layout, preview?)`, `renderJpeg(image, document)` |
| `document.ts` | JSON encode/decode, clone shapes |

**Rendering:** Canvas 2D API. Load original via `createImageBitmap` / `HTMLImageElement` from `/api/media/{primary_photo}/download?inline=1`. Flatten: draw image full size, paint shapes at image pixel dimensions, `canvas.toBlob('image/jpeg', 0.9)`.

**Tests:** Port cases from `app/test/photo_annotation_test.dart` — JSON roundtrip, norm mapping, golden optional (canvas snapshot).

### 4.2 Editor UI

`web/components/photo-annotation/`:

| Component | Role |
| --- | --- |
| `PhotoAnnotationEditor` | Full-viewport overlay; load photo + overlay; Save / Close |
| `AnnotationCanvas` | Pointer events: pan tools + tap-for-text; undo stack |
| `AnnotationToolbar` | Tool row, colors, undo/redo/clear — mirror mobile layout |
| `TextLabelDialog` | Modal; 80 char max |

**Interaction mapping:**

| Mobile | Web |
| --- | --- |
| Long-press peek original | Hold pointer on canvas (already in lightbox view mode) |
| Drag stroke | `pointerdown/move/up` with capture |
| Text tap | `click` when text tool active |
| Full-screen scaffold | Fixed overlay `z-index` above lightbox; `Esc` → discard confirm |

**Entry:**

- Lightbox footer: **Annotate** (primary outline button) when `!readOnly && primary_photo`.
- Opens editor over lightbox; on save, close editor + refresh job state (`router.refresh()` + local media map update).

Optional URL: `/jobs/:id?item=:itemId&annotate=1` for deep-link (closes on save).

### 4.3 Save flow (web client)

```
1. User taps Save
2. document = { version: 2, shapes }
3. If document empty:
     DELETE existing annotation_overlay + annotated_render media IDs
   Else:
     jpegBlob = renderJpeg(originalImage, document)
     jsonBlob = Blob(document.encode())
     mint + PUT + complete for overlay (application/json)
     mint + PUT + complete for render (image/jpeg)
     DELETE superseded overlay/render IDs if re-saving
4. PUT /api/jobs/:jobId/items/:itemId { updated_at: now }  // bump sync cursor
5. Optimistic: update mediaByItem in client state; toast on failure
```

Use **new UUIDs** for each save (same as mobile insert-new-rows pattern) unless we add true upsert-by-role on API.

**Original source:** Always flatten onto `primary_photo` bytes, never onto an existing annotated render.

**Loading editor:** Fetch overlay via `annotation_overlay` media download; decode JSON. If overlay missing but `annotated_render` exists (legacy sync), open with **empty shapes** and show one-time notice: *“Mark-up was flattened on sync; redraw or save to replace.”*

---

## 5. Implementation phases

### Phase A — Platform fixes (~2–3 days)

1. API: `application/json` mime; media soft-delete handler.
2. Mobile sync: upload overlay; correct `annotated_render` role; fix pull role mapping.
3. Web BFF: media create, complete, delete proxies.
4. Thumb cache invalidation on media complete (annotated roles).
5. Pass `read_only` into `JobDetailClient`; read-only banner + gating.

**Exit criteria:** Phone-annotated photo syncs to server with three media rows (`primary_photo`, `annotation_overlay`, `annotated_render`); web can download overlay JSON.

### Phase B — Renderer port (~2 days)

1. `web/lib/photo-annotation/*` + unit tests.
2. Visual spot-check against mobile export (same photo + shapes → perceptually identical markup).

**Exit criteria:** Tests pass; manual compare one annotated photo mobile vs web render.

### Phase C — Editor UI (~3–4 days)

1. Canvas + toolbar + dialogs.
2. Wire into lightbox; discard/save confirms.
3. Keyboard: `Ctrl/Cmd+Z` undo, `Shift+Ctrl+Z` redo; `Esc` discard.

**Exit criteria:** Can draw all shape types; undo/redo/clear; text labels; no save yet.

### Phase D — Save & sync (~2–3 days)

1. Upload pipeline; clear path; item timestamp bump.
2. Optimistic timeline refresh; annotated badge updates.
3. Error handling + toasts.

**Exit criteria:** Save on web → mobile pull shows same strokes; mobile save → web reload edits same strokes.

### Phase E — QA & docs (~1 day)

1. Read-only member cannot annotate.
2. Large photos (12 MP+) performance smoke test.
3. Update `high-level-design.md` implementation table + `web-dashboard-design.md` §4.2 (annotate in lightbox).
4. Manual test plan below.

**Total estimate:** ~10–13 dev days (one engineer), assuming Phase A mobile changes land in parallel.

---

## 6. Test plan

| # | Scenario | Expected |
| --- | --- | --- |
| T1 | Open photo with no annotations → Annotate | Empty editor on original |
| T2 | Phone-annotated photo → web Annotate | Strokes loaded; editable |
| T3 | Web save new arrow | Grid/lightbox show render; mobile syncs overlay |
| T4 | Web edit existing strokes | Old render replaced; mobile sees update |
| T5 | Clear all + Save | Annotations removed; display falls back to original |
| T6 | Discard with dirty canvas | Confirm; no server change |
| T7 | Unassigned member | No Annotate button; API 403 if forced |
| T8 | All six tools + five colors | Matches mobile stroke appearance |
| T9 | Text label 80 chars | Truncation/enforcement |
| T10 | Legacy: annotated JPEG as `primary_photo` only | Editor opens empty + notice (until backfill) |

---

## 7. Risks & decisions

| Risk | Mitigation |
| --- | --- |
| Overlay never synced historically | Phase A mobile fix + optional backfill; legacy notice in editor |
| Original missing on server | Block save with clear error; require re-sync from device that has original |
| Large image client-side render | Cap canvas dimension (e.g. max 4096 long edge) with warning; mobile uses same source pixels |
| Concurrent mobile + web edit | Last `items.updated_at` wins; acceptable for MVP |
| Dashboard “no Save buttons” principle | Explicit Save for annotation only (matches mobile; complex transactional upload) |

**Open product question:** Should owners annotate on **any** job while members only on assigned jobs? **Recommendation:** Same rule as captions — follow `read_only` / assignment.

**Open technical question:** Dedicated `PUT /items/:id/annotations` multipart endpoint vs client-side render + two media uploads? **Recommendation:** Two media uploads — reuses sync model, no server-side image library in Go.

---

## 8. Files to touch (summary)

| Area | Files |
| --- | --- |
| API | `services/api/internal/jobs/mime.go`, `media.go`, new delete handler, `server.go` routes |
| Mobile sync | `app/lib/domain/models/media_file.dart`, `app/lib/sync/sync_engine.dart` |
| Web lib | `web/lib/photo-annotation/*`, `web/lib/photo-media.ts` (extend) |
| Web UI | `web/components/photo-annotation/*`, `job-detail-client.tsx`, `job-detail.module.css` |
| Web BFF | `web/app/api/items/[itemId]/media-files/route.ts`, `web/app/api/media/[mediaId]/complete/route.ts`, `web/app/api/media/[mediaId]/route.ts` |
| Docs | `docs/high-level-design.md`, `docs/web-dashboard-design.md` |

---

## 9. Done definition

Photo annotation on web is **done** when:

1. All rows in §1 “Required for parity” are checked.
2. T1–T10 pass on staging with real sync (phone ↔ dashboard).
3. Phase A platform fixes are deployed (web-only editor without sync fixes is **not** shippable).
