"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Item, ItemTag, Job, MediaFile, Tag } from "@/lib/api-jobs";
import { useSyncPoll } from "@/hooks/use-sync-poll";
import { useUrlQueryParam, useUrlSetParam } from "@/hooks/use-url-filter-state";
import { formatDate, formatDayKey, formatTime } from "@/lib/format";
import {
  buildActiveFilterLabels,
  buildTagsByItem,
  filterTimelineItems,
  tagsUsedInJob,
  type ItemKind,
} from "@/lib/search";
import { buildJobPutPayload } from "@/lib/job-form";
import { fetchJobDelta, mergeJobBundle, pollJobCursor } from "@/lib/sync-cursor";
import { JobFormDrawer } from "@/components/job-form-drawer";
import { SYNC_POLL } from "@/lib/sync-poll-config";
import { getPhotoMedia, itemThumbUrl, mediaDownloadUrl } from "@/lib/photo-media";
import { PhotoAnnotationEditor } from "@/components/photo-annotation/photo-annotation-editor";
import { PageShell } from "@/components/page-shell";
import {
  TimelineFilteredEmpty,
  TimelineSearchPanel,
  TimelineSectionHeader,
} from "@/components/timeline-search-panel";
import { TimelineTagFilterSheet } from "@/components/timeline-tag-filter-sheet";
import { MobileAddSheet } from "@/components/mobile-add-sheet";
import { MobileFilterSheet } from "@/components/mobile-filter-sheet";
import {
  MobileDayTimeline,
  MobileQuickTagRow,
  MobileSummaryChips,
  MobileTimelineToolbar,
} from "@/components/mobile-timeline";
import styles from "./job-detail.module.css";

const TIMELINE_KIND_CHIPS: { id: ItemKind; label: string }[] = [
  { id: "photo", label: "Photos" },
  { id: "voice", label: "Voice" },
  { id: "note", label: "Notes" },
  { id: "file", label: "Files" },
];

type Props = {
  job: Job;
  items: Item[];
  mediaFiles: MediaFile[];
  tags?: Tag[];
  itemTags?: ItemTag[];
  workspaceId: string;
  readOnly?: boolean;
};

async function fetchWorkspaceTags(workspaceId: string): Promise<Tag[]> {
  const res = await fetch(`/api/workspaces/${workspaceId}/tags`, { cache: "no-store" });
  const data = await res.json();
  if (!res.ok) return [];
  return (data.tags as Tag[] | undefined) ?? [];
}

type TimelineSegment =
  | { type: "photos"; items: Item[] }
  | { type: "row"; item: Item };

type JobStatus = Job["status"];

const JOB_STATUSES: { value: JobStatus; label: string }[] = [
  { value: "planning", label: "Planning" },
  { value: "in_progress", label: "In progress" },
  { value: "completed", label: "Completed" },
];

export function JobDetailClient({
  job: initialJob,
  items: initialItems,
  mediaFiles: initialMediaFiles,
  tags: initialTags = [],
  itemTags: initialItemTags = [],
  workspaceId,
  readOnly = false,
}: Props) {
  const router = useRouter();
  const [job, setJob] = useState(initialJob);
  const [items, setItems] = useState(initialItems ?? []);
  const [mediaFiles, setMediaFiles] = useState(initialMediaFiles ?? []);
  const [noteBody, setNoteBody] = useState("");
  const [noteCaption, setNoteCaption] = useState("");
  const [saving, setSaving] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [statusMenuOpen, setStatusMenuOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [noteMessage, setNoteMessage] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const statusMenuRef = useRef<HTMLDivElement>(null);
  const [fieldUpdateBanner, setFieldUpdateBanner] = useState(false);
  const [lightbox, setLightbox] = useState<{ itemId: string; mediaId?: string } | null>(null);
  const [annotatingItemId, setAnnotatingItemId] = useState<string | null>(null);
  const [addSheetOpen, setAddSheetOpen] = useState(false);
  const [mobileNoteOpen, setMobileNoteOpen] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [mobileFilterOpen, setMobileFilterOpen] = useState(false);
  const [tagFilterOpen, setTagFilterOpen] = useState(false);
  const [workspaceTags, setWorkspaceTags] = useState<Tag[]>(initialTags);
  const mobileMenuRef = useRef<HTMLDivElement>(null);
  const noteBodyRef = useRef<HTMLTextAreaElement>(null);
  const searchParams = useSearchParams();
  const [filtersExpanded, setFiltersExpanded] = useState(
    () => searchParams.has("kind") || searchParams.has("tag"),
  );
  const searchRef = useRef<HTMLInputElement>(null);
  const [tags, setTags] = useState(initialTags);
  const [itemTags, setItemTags] = useState(initialItemTags);

  useEffect(() => {
    if (searchParams.has("kind") || searchParams.has("tag")) setFiltersExpanded(true);
  }, [searchParams]);
  const [query, setQuery] = useUrlQueryParam("q");
  const { values: kindFilter, toggle: toggleKind, setValues: setKindFilter } = useUrlSetParam("kind");
  const { values: tagFilter, toggle: toggleTag, setValues: setTagFilter } = useUrlSetParam("tag");
  const cursorRef = useRef(
    jobCursorValue(job.last_activity_at ?? job.updated_at, job.updated_at),
  );
  const itemsRef = useRef(items);
  const mediaRef = useRef(mediaFiles);
  const tagsRef = useRef(tags);
  const itemTagsRef = useRef(itemTags);
  itemsRef.current = items;
  mediaRef.current = mediaFiles;
  tagsRef.current = tags;
  itemTagsRef.current = itemTags;

  useEffect(() => {
    setJob(initialJob);
  }, [initialJob]);

  useEffect(() => {
    setItems(initialItems ?? []);
  }, [initialItems]);

  useEffect(() => {
    setMediaFiles(initialMediaFiles ?? []);
  }, [initialMediaFiles]);

  useEffect(() => {
    setTags(initialTags);
  }, [initialTags]);

  useEffect(() => {
    setItemTags(initialItemTags);
  }, [initialItemTags]);

  useEffect(() => {
    let cancelled = false;
    fetchWorkspaceTags(workspaceId).then((next) => {
      if (!cancelled && next.length > 0) setWorkspaceTags(next);
    });
    return () => {
      cancelled = true;
    };
  }, [workspaceId]);

  useEffect(() => {
    cursorRef.current = jobCursorValue(job.last_activity_at ?? job.updated_at, job.updated_at);
  }, [job.last_activity_at, job.updated_at]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 2500);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    if (!statusMenuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (statusMenuRef.current && !statusMenuRef.current.contains(event.target as Node)) {
        setStatusMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [statusMenuOpen]);

  useEffect(() => {
    if (!mobileMenuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (mobileMenuRef.current && !mobileMenuRef.current.contains(event.target as Node)) {
        setMobileMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [mobileMenuOpen]);

  const onJobChanged = useCallback(
    async (result: { cursor: string | null }) => {
      const since = cursorRef.current;
      const nextCursor = result.cursor ?? since;
      const delta = await fetchJobDelta(job.id, since);
      const hasItemDelta =
        (delta.items?.length ?? 0) > 0 || (delta.media_files?.length ?? 0) > 0;

      // Job metadata or timeline changed without item rows in the delta window.
      if (!hasItemDelta && nextCursor !== since) {
        cursorRef.current = nextCursor;
        if (delta.job) setJob(delta.job);
        else router.refresh();
        return;
      }

      const merged = mergeJobBundle(
        itemsRef.current,
        mediaRef.current,
        delta,
        tagsRef.current,
        itemTagsRef.current,
      );
      if (merged.job) {
        setJob(merged.job);
      }
      if (merged.added > 0) {
        setItems(merged.items);
        setMediaFiles(merged.mediaFiles);
        setTags(merged.tags);
        setItemTags(merged.itemTags);
        setFieldUpdateBanner(true);
        window.setTimeout(() => setFieldUpdateBanner(false), SYNC_POLL.updatedBannerMs);
      } else if (hasItemDelta) {
        setItems(merged.items);
        setMediaFiles(merged.mediaFiles);
        setTags(merged.tags);
        setItemTags(merged.itemTags);
      }
      cursorRef.current = nextCursor;
    },
    [job.id, router],
  );

  useSyncPoll({
    baseIntervalMs: SYNC_POLL.jobDetailMs,
    poll: (etag) => pollJobCursor(job.id, etag),
    onChanged: onJobChanged,
  });

  async function refresh() {
    setRefreshing(true);
    try {
      router.refresh();
    } finally {
      setRefreshing(false);
    }
  }

  const mediaByItem = useMemo(() => {
    const map = new Map<string, MediaFile[]>();
    for (const mf of mediaFiles ?? []) {
      if (mf.status !== "uploaded") continue;
      const list = map.get(mf.item_id) ?? [];
      list.push(mf);
      map.set(mf.item_id, list);
    }
    return map;
  }, [mediaFiles]);

  const allTags = useMemo(() => {
    const byId = new Map<string, Tag>();
    for (const tag of workspaceTags) byId.set(tag.id, tag);
    for (const tag of tags) byId.set(tag.id, tag);
    return [...byId.values()].sort((a, b) => a.name.localeCompare(b.name));
  }, [workspaceTags, tags]);

  const tagsByItem = useMemo(() => buildTagsByItem(allTags, itemTags), [allTags, itemTags]);
  const tagsInJob = useMemo(() => tagsUsedInJob(tagsByItem, items), [tagsByItem, items]);

  const filteredItems = useMemo(
    () =>
      filterTimelineItems(
        items,
        mediaByItem,
        tagsByItem,
        query,
        kindFilter.size > 0 ? (kindFilter as ReadonlySet<ItemKind>) : undefined,
        tagFilter.size > 0 ? tagFilter : undefined,
      ),
    [items, mediaByItem, tagsByItem, query, kindFilter, tagFilter],
  );

  const photoItems = useMemo(() => photoItemsInJob(filteredItems), [filteredItems]);

  const grouped = useMemo(() => groupByDate(filteredItems), [filteredItems]);
  const sortedDays = useMemo(
    () => Object.entries(grouped).sort(([a], [b]) => b.localeCompare(a)),
    [grouped],
  );

  const hasActiveFilters =
    query.trim().length > 0 || kindFilter.size > 0 || tagFilter.size > 0;

  const kindCounts = useMemo(() => {
    const counts = { photo: 0, voice: 0, note: 0, file: 0 };
    for (const item of items) {
      if (item.kind in counts) counts[item.kind as keyof typeof counts] += 1;
    }
    return counts;
  }, [items]);

  function clearFilters() {
    setQuery("");
    setKindFilter(new Set());
    setTagFilter(new Set());
    setFiltersExpanded(false);
  }

  function applyTagFilter(next: Set<string>) {
    setTagFilter(next);
    if (next.size > 0) setFiltersExpanded(true);
  }

  const activeFilterSummary = buildActiveFilterLabels(
    query,
    kindFilter as ReadonlySet<ItemKind>,
    tagFilter,
    allTags,
  ).join(" · ");

  async function addNote() {
    if (!noteBody.trim()) return;
    setSaving(true);
    setNoteMessage(null);
    try {
      const id = crypto.randomUUID();
      const now = new Date().toISOString();
      const res = await fetch(`/api/jobs/${job.id}/items/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          kind: "note",
          body: noteBody.trim(),
          caption: noteCaption.trim() || null,
          captured_at: now,
          created_at: now,
          updated_at: now,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || "Could not add note");
      setItems((prev) => [data, ...prev]);
      setNoteBody("");
      setNoteCaption("");
      setNoteMessage("Saved");
      router.refresh();
    } catch (err) {
      setNoteMessage(err instanceof Error ? err.message : "Could not save");
    } finally {
      setSaving(false);
    }
  }

  async function updateJobStatus(nextStatus: JobStatus) {
    if (readOnly || nextStatus === job.status) {
      setStatusMenuOpen(false);
      return;
    }
    setUpdatingStatus(true);
    setToast(null);
    try {
      const res = await fetch(`/api/jobs/${job.id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(buildJobPutPayload(job, { status: nextStatus })),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || "Could not update status");
      setJob(data);
      setStatusMenuOpen(false);
      setToast("Status updated");
      router.refresh();
    } catch (err) {
      setToast(err instanceof Error ? err.message : "Could not update status");
    } finally {
      setUpdatingStatus(false);
    }
  }

  async function saveCaption(item: Item, caption: string) {
    const now = new Date().toISOString();
    const res = await fetch(`/api/jobs/${job.id}/items/${item.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        kind: item.kind,
        body: item.body,
        caption: caption || null,
        captured_at: item.captured_at,
        created_at: item.created_at,
        updated_at: now,
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not save");
    setItems((prev) => prev.map((it) => (it.id === item.id ? data : it)));
    router.refresh();
  }

  const openPhoto = useCallback((itemId: string, mediaId?: string) => {
    setLightbox({ itemId, mediaId });
  }, []);

  function handleAnnotationSaved(itemId: string, updatedMedia: MediaFile[]) {
    setMediaFiles((prev) => {
      const rest = prev.filter((m) => m.item_id !== itemId);
      return [...rest, ...updatedMedia];
    });
    router.refresh();
  }

  const annotatingItem = annotatingItemId ? items.find((i) => i.id === annotatingItemId) : null;
  const locationLine = [job.address, job.client_name].filter(Boolean).join(" · ");
  const subtitle = [job.client_name, job.address].filter(Boolean).join(" · ");
  const hasExtraDetails = Boolean(job.job_number || job.start_date || job.end_date || job.notes);

  function openMobileNoteCompose() {
    setMobileNoteOpen(true);
    window.requestAnimationFrame(() => noteBodyRef.current?.focus());
  }

  return (
    <>
    <header className={`${styles.mobileDetailHeader} mobileOnly`}>
      <div className={styles.mobileNavRow}>
        <Link href="/jobs" className={styles.mobileBack} aria-label="Back to jobs">
          ←
        </Link>
        <div className={styles.mobileNavActions}>
          {!readOnly && (
            <button
              type="button"
              className={styles.jobSettingsBtn}
              onClick={() => setEditOpen(true)}
              aria-label="Job settings"
            >
              <JobSettingsIcon />
            </button>
          )}
        <div className={styles.mobileDetailMenu} ref={mobileMenuRef}>
          <button
            type="button"
            className={styles.mobileMenuBtn}
            onClick={() => setMobileMenuOpen((v) => !v)}
            aria-expanded={mobileMenuOpen}
            aria-label="Job menu"
          >
            ⋮
          </button>
          {mobileMenuOpen && (
            <div className={styles.mobileMenuDropdown}>
              <button type="button" onClick={() => { refresh(); setMobileMenuOpen(false); }} disabled={refreshing}>
                {refreshing ? "Refreshing…" : "Refresh"}
              </button>
              {!readOnly && JOB_STATUSES.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  disabled={updatingStatus || job.status === option.value}
                  onClick={() => { updateJobStatus(option.value); setMobileMenuOpen(false); }}
                >
                  Set {option.label}
                </button>
              ))}
            </div>
          )}
        </div>
        </div>
      </div>
      <h1 className={styles.mobileDetailTitle}>{job.name}</h1>
      {locationLine && <p className={styles.mobileDetailLocation}>{locationLine}</p>}
      <span className={`${styles.mobileDetailStatus} ${styles[`status_${job.status}`]}`}>
        {job.status === "completed" && <span aria-hidden>✓ </span>}
        {job.status.replace(/_/g, " ")}
      </span>
      {items.length > 0 && (
        <MobileSummaryChips
          counts={kindCounts}
          kindFilter={kindFilter as ReadonlySet<ItemKind>}
          onToggleKind={(kind) => toggleKind(kind)}
        />
      )}
      {items.length > 0 && (
        <MobileTimelineToolbar
          query={query}
          onQueryChange={setQuery}
          onOpenFilters={() => setMobileFilterOpen(true)}
          onOpenTagFilter={() => setTagFilterOpen(true)}
          hasFilters={hasActiveFilters}
          hasTagFilter={tagFilter.size > 0}
          inputRef={searchRef}
        />
      )}
      {items.length > 0 && (
        <MobileQuickTagRow
          allTags={allTags}
          tagsInJob={tagsInJob}
          tagFilter={tagFilter}
          onToggleTag={toggleTag}
          onOpenTagFilter={() => setTagFilterOpen(true)}
        />
      )}
      {items.length > 0 && hasActiveFilters && (
        <button
          type="button"
          className={styles.mobileFilterSummary}
          onClick={() => {
            if (tagFilter.size > 0) setTagFilterOpen(true);
            else if (kindFilter.size > 0) setMobileFilterOpen(true);
            else searchRef.current?.focus();
          }}
        >
          <span>{activeFilterSummary}</span>
          <span
            className={styles.mobileFilterSummaryClear}
            onClick={(event) => {
              event.stopPropagation();
              clearFilters();
            }}
            role="button"
            tabIndex={0}
            aria-label="Clear filters"
          >
            ×
          </span>
        </button>
      )}
    </header>

    <PageShell
      className={styles.detailShell}
      headerClassName="desktopOnly"
      title={job.name}
      subtitle={subtitle || "Job timeline"}
      action={
        <div className={styles.headerActions}>
          {!readOnly && (
            <button
              type="button"
              className={styles.jobSettingsBtn}
              onClick={() => setEditOpen(true)}
              aria-label="Job settings"
              title="Job settings"
            >
              <JobSettingsIcon />
            </button>
          )}
          <div className={styles.statusPicker} ref={statusMenuRef}>
            {readOnly ? (
              <span className={`${styles.statusPill} ${styles[`status_${job.status}`]}`}>
                {job.status.replace(/_/g, " ")}
              </span>
            ) : (
              <button
                type="button"
                className={`${styles.statusPill} ${styles.statusPillBtn} ${styles[`status_${job.status}`]}`}
                onClick={() => setStatusMenuOpen((open) => !open)}
                disabled={updatingStatus}
                aria-haspopup="listbox"
                aria-expanded={statusMenuOpen}
              >
                {job.status.replace(/_/g, " ")}
                <span className={styles.statusChevron} aria-hidden>
                  ▾
                </span>
              </button>
            )}
            {statusMenuOpen && !readOnly && (
              <div className={styles.statusMenu} role="listbox" aria-label="Job status">
                {JOB_STATUSES.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    role="option"
                    aria-selected={job.status === option.value}
                    className={
                      job.status === option.value
                        ? `${styles.statusOption} ${styles.statusOptionActive}`
                        : styles.statusOption
                    }
                    onClick={() => updateJobStatus(option.value)}
                    disabled={updatingStatus}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            )}
          </div>
          <button type="button" className={styles.refreshBtn} onClick={refresh} disabled={refreshing}>
            {refreshing ? "Refreshing…" : "Refresh"}
          </button>
          <Link href="/jobs" className={styles.backLink}>
            ← All jobs
          </Link>
        </div>
      }
    >
      {toast && (
        <p className={styles.toast} role="status">
          {toast}
        </p>
      )}
      {fieldUpdateBanner && (
        <p className={styles.updateBanner} role="status">
          Updated — new items from the field
        </p>
      )}
      {readOnly && (
        <p className={styles.readOnlyBanner}>
          You&apos;re viewing this job. Ask the owner for assignment to edit.
        </p>
      )}

      {!readOnly && (
        <section className={`${styles.detailsCard} desktopOnly`}>
          <h2 className={styles.detailsCardTitle}>Job details</h2>
          {hasExtraDetails ? (
            <dl className={styles.detailsList}>
              {job.job_number && (
                <>
                  <dt>Job number</dt>
                  <dd>{job.job_number}</dd>
                </>
              )}
              {(job.start_date || job.end_date) && (
                <>
                  <dt>Dates</dt>
                  <dd>{[job.start_date, job.end_date].filter(Boolean).join(" → ")}</dd>
                </>
              )}
              {job.notes && (
                <>
                  <dt>Notes</dt>
                  <dd>{job.notes}</dd>
                </>
              )}
            </dl>
          ) : (
            <p className={styles.detailsEmpty}>
              No job number, dates, or notes yet. Use the settings icon above to add them.
            </p>
          )}
        </section>
      )}

      {items.length > 0 && (
        <div className="desktopOnly">
          <TimelineSearchPanel
            query={query}
            onQueryChange={setQuery}
            kindFilter={kindFilter as ReadonlySet<ItemKind>}
            onToggleKind={(kind) => toggleKind(kind)}
            tagFilter={tagFilter}
            onToggleTag={toggleTag}
            onOpenTagFilter={() => setTagFilterOpen(true)}
            allTags={allTags}
            tagsInJob={tagsInJob}
            expanded={filtersExpanded}
            onExpandedChange={setFiltersExpanded}
            onClearFilters={clearFilters}
            shownCount={filteredItems.length}
            totalCount={items.length}
            inputRef={searchRef}
          />
        </div>
      )}

      {!readOnly && (
      <section
        className={mobileNoteOpen ? `${styles.compose} ${styles.composeMobileOpen}` : styles.compose}
        id="note-compose"
      >
        <h2>Add text note</h2>
        <input
          placeholder="Caption (optional)"
          value={noteCaption}
          onChange={(e) => setNoteCaption(e.target.value)}
        />
        <textarea
          ref={noteBodyRef}
          placeholder="Note body"
          rows={3}
          value={noteBody}
          onChange={(e) => setNoteBody(e.target.value)}
        />
        <div className={styles.composeActions}>
          <button type="button" className={styles.primary} disabled={saving} onClick={addNote}>
            {saving ? "Saving…" : "Add note"}
          </button>
          {noteMessage && <span className={styles.saved}>{noteMessage}</span>}
        </div>
      </section>
      )}

      {items.length === 0 ? (
        <p className={styles.empty}>No timeline items yet.</p>
      ) : (
        <>
          <div className="desktopOnly">
            <TimelineSectionHeader
              shownCount={filteredItems.length}
              totalCount={items.length}
              hasFilters={hasActiveFilters}
            />
          </div>
          {filteredItems.length === 0 ? (
            <TimelineFilteredEmpty onClear={clearFilters} />
          ) : (
            sortedDays.map(([dayKey, dayItems]) => (
              <div key={dayKey}>
                <div className="mobileOnly">
                  <MobileDayTimeline
                    dayKey={dayKey}
                    items={dayItems}
                    mediaByItem={mediaByItem}
                    tagsByItem={tagsByItem}
                    onOpenPhoto={openPhoto}
                    onToggleTag={toggleTag}
                    tagFilter={tagFilter}
                  />
                </div>
                <section className={`${styles.dayGroup} desktopOnly`}>
                  <h3>{formatDate(`${dayKey}T12:00:00.000Z`)}</h3>
                  <div className={styles.dayContent}>
                    {segmentDayItems(dayItems).map((seg, i) =>
                      seg.type === "photos" ? (
                        <PhotoGrid
                          key={`g-${dayKey}-${i}`}
                          items={seg.items}
                          mediaByItem={mediaByItem}
                          tagsByItem={tagsByItem}
                          tagFilter={tagFilter}
                          onOpen={openPhoto}
                          onToggleTag={toggleTag}
                        />
                      ) : (
                        <ul key={`r-${seg.item.id}`} className={styles.timelineRows}>
                          <li>
                            <TimelineRow
                              item={seg.item}
                              media={mediaByItem.get(seg.item.id) ?? []}
                              tags={tagsByItem.get(seg.item.id) ?? []}
                              tagFilter={tagFilter}
                              onToggleTag={toggleTag}
                            />
                          </li>
                        </ul>
                      ),
                    )}
                  </div>
                </section>
              </div>
            ))
          )}
        </>
      )}

      {lightbox && (
        <PhotoLightbox
          items={filteredItems}
          photoItems={photoItems}
          mediaByItem={mediaByItem}
          lightbox={lightbox}
          readOnly={readOnly}
          onClose={() => setLightbox(null)}
          onNavigate={(itemId, mediaId) => setLightbox({ itemId, mediaId })}
          onSaveCaption={saveCaption}
          onAnnotate={(itemId) => {
            setLightbox(null);
            setAnnotatingItemId(itemId);
          }}
        />
      )}

      {annotatingItem && (
        <PhotoAnnotationEditor
          jobId={job.id}
          item={annotatingItem}
          media={mediaByItem.get(annotatingItem.id) ?? []}
          onClose={() => setAnnotatingItemId(null)}
          onSaved={(updated) => handleAnnotationSaved(annotatingItem.id, updated)}
        />
      )}

      {editOpen && !readOnly && (
        <JobFormDrawer
          key={job.updated_at}
          mode="edit"
          job={job}
          onClose={() => setEditOpen(false)}
          onSaved={(updated) => {
            setJob(updated);
            setToast("Job details saved");
          }}
        />
      )}
    </PageShell>

    {!readOnly && (
      <button
        type="button"
        className={`${styles.mobileAddFab} mobileOnly`}
        onClick={() => setAddSheetOpen(true)}
        aria-label="Add"
      >
        + Add
      </button>
    )}

    <MobileAddSheet
      open={addSheetOpen}
      onClose={() => setAddSheetOpen(false)}
      jobName={job.name}
      readOnly={readOnly}
      onAddNote={openMobileNoteCompose}
    />

    <MobileFilterSheet
      open={mobileFilterOpen}
      onClose={() => setMobileFilterOpen(false)}
      title="Filter timeline"
      chips={TIMELINE_KIND_CHIPS}
      activeChipIds={kindFilter}
      onToggleChip={(id) => toggleKind(id as ItemKind)}
      onClear={() => setKindFilter(new Set())}
    />

    <TimelineTagFilterSheet
      open={tagFilterOpen}
      onClose={() => setTagFilterOpen(false)}
      allTags={allTags}
      tagsInJob={tagsInJob}
      selectedTagIds={tagFilter}
      onApply={applyTagFilter}
    />
    </>
  );
}

function jobCursorValue(lastActivityAt: string, updatedAt: string): string {
  return new Date(updatedAt) > new Date(lastActivityAt) ? updatedAt : lastActivityAt;
}

function PhotoGrid({
  items,
  mediaByItem,
  tagsByItem,
  tagFilter,
  onOpen,
  onToggleTag,
}: {
  items: Item[];
  mediaByItem: Map<string, MediaFile[]>;
  tagsByItem: Map<string, Tag[]>;
  tagFilter: ReadonlySet<string>;
  onOpen: (itemId: string, mediaId?: string) => void;
  onToggleTag: (tagId: string) => void;
}) {
  return (
    <div className={styles.photoGrid} role="group" aria-label="Photos">
      {items.map((item) => (
        <PhotoCell
          key={item.id}
          item={item}
          media={mediaByItem.get(item.id) ?? []}
          tags={tagsByItem.get(item.id) ?? []}
          tagFilter={tagFilter}
          onOpen={onOpen}
          onToggleTag={onToggleTag}
        />
      ))}
    </div>
  );
}

function TagRow({
  tags,
  tagFilter,
  onToggleTag,
}: {
  tags: Tag[];
  tagFilter: ReadonlySet<string>;
  onToggleTag: (tagId: string) => void;
}) {
  if (tags.length === 0) return null;
  return (
    <div className={styles.itemTagRow}>
      {tags.map((tag) => (
        <button
          key={tag.id}
          type="button"
          className={`${styles.itemTag} ${tagFilter.has(tag.id) ? styles.itemTagActive : ""}`}
          aria-pressed={tagFilter.has(tag.id)}
          onClick={() => onToggleTag(tag.id)}
        >
          {tag.name}
        </button>
      ))}
    </div>
  );
}

function PhotoCell({
  item,
  media,
  tags,
  tagFilter,
  onOpen,
  onToggleTag,
}: {
  item: Item;
  media: MediaFile[];
  tags: Tag[];
  tagFilter: ReadonlySet<string>;
  onOpen: (itemId: string, mediaId?: string) => void;
  onToggleTag: (tagId: string) => void;
}) {
  const { display, hasAnnotations } = getPhotoMedia(media);
  const time = formatTime(item.captured_at);
  const label = `Photo, ${time}, ${item.caption || "no caption"}${hasAnnotations ? ", annotated" : ""}`;

  if (!display) {
    return (
      <div className={styles.photoCellPending} aria-label={`${label}, uploading`}>
        Uploading…
      </div>
    );
  }

  return (
    <div className={styles.photoCellWrap}>
      <button
        type="button"
        className={styles.photoCell}
        onClick={() => onOpen(item.id, display.id)}
        aria-label={label}
      >
        <span className={styles.photoThumbWrap}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            key={display.updated_at}
            src={itemThumbUrl(item.id, display, 384)}
            alt=""
            className={styles.photoThumb}
            loading="lazy"
          />
          {hasAnnotations && (
            <span className={styles.photoAnnotatedBadge} aria-hidden>
              ✎
            </span>
          )}
          <span className={styles.photoTime}>{time}</span>
        </span>
        <p className={item.caption ? styles.photoCaption : `${styles.photoCaption} ${styles.photoCaptionEmpty}`}>
          {item.caption || "No caption"}
        </p>
      </button>
      <TagRow tags={tags} tagFilter={tagFilter} onToggleTag={onToggleTag} />
    </div>
  );
}

function TimelineRow({
  item,
  media,
  tags,
  tagFilter,
  onToggleTag,
}: {
  item: Item;
  media: MediaFile[];
  tags: Tag[];
  tagFilter: ReadonlySet<string>;
  onToggleTag: (tagId: string) => void;
}) {
  const preview =
    item.kind === "note"
      ? item.body
      : item.kind === "voice"
        ? item.caption
        : null;

  return (
    <article className={styles.timelineRow}>
      <div className={styles.timelineRowMain}>
        <div className={styles.timelineRowIcon} aria-hidden>
          {item.kind === "voice" && <VoiceIcon />}
          {item.kind === "note" && <NoteIcon />}
          {item.kind === "file" && <FileIcon />}
        </div>
        <div className={styles.timelineRowBody}>
          <div className={styles.timelineRowMeta}>
            <time dateTime={item.captured_at}>{formatTime(item.captured_at)}</time>
            <span className={styles.kind}>{item.kind}</span>
          </div>
          {item.kind === "note" && item.body && <p className={styles.body}>{item.body}</p>}
          {preview && item.kind === "voice" && <p className={styles.rowPreview}>{preview}</p>}
          <RowMedia item={item} media={media} />
          <TagRow tags={tags} tagFilter={tagFilter} onToggleTag={onToggleTag} />
        </div>
      </div>
    </article>
  );
}

function RowMedia({ item, media }: { item: Item; media: MediaFile[] }) {
  if (item.kind === "voice") {
    const voice = media.find((m) => m.role === "voice_note") ?? media[0];
    if (!voice) {
      return <p className={styles.mediaPending}>Voice note pending upload…</p>;
    }
    return (
      <audio controls preload="none" className={styles.audio} src={`/api/media/${voice.id}/download?inline=1`}>
        <track kind="captions" />
      </audio>
    );
  }

  if (item.kind === "file") {
    const file = media.find((m) => m.role === "file") ?? media[0];
    if (!file) {
      return <p className={styles.mediaPending}>File pending upload…</p>;
    }
    const label = file.original_filename || "Download file";
    return (
      <a className={styles.fileLink} href={`/api/media/${file.id}/download`}>
        ↓ {label}
      </a>
    );
  }

  return null;
}

function PhotoLightbox({
  items,
  photoItems,
  mediaByItem,
  lightbox,
  readOnly,
  onClose,
  onNavigate,
  onSaveCaption,
  onAnnotate,
}: {
  items: Item[];
  photoItems: Item[];
  mediaByItem: Map<string, MediaFile[]>;
  lightbox: { itemId: string; mediaId?: string };
  readOnly: boolean;
  onClose: () => void;
  onNavigate: (itemId: string, mediaId?: string) => void;
  onSaveCaption: (item: Item, caption: string) => Promise<void>;
  onAnnotate: (itemId: string) => void;
}) {
  const index = photoItems.findIndex((p) => p.id === lightbox.itemId);
  const item = items.find((i) => i.id === lightbox.itemId);
  const hasPrev = index > 0;
  const hasNext = index >= 0 && index < photoItems.length - 1;

  const goPrev = useCallback(() => {
    if (!hasPrev) return;
    const prev = photoItems[index - 1];
    const { display } = getPhotoMedia(mediaByItem.get(prev.id) ?? []);
    onNavigate(prev.id, display?.id);
  }, [hasPrev, index, photoItems, mediaByItem, onNavigate]);

  const goNext = useCallback(() => {
    if (!hasNext) return;
    const next = photoItems[index + 1];
    const { display } = getPhotoMedia(mediaByItem.get(next.id) ?? []);
    onNavigate(next.id, display?.id);
  }, [hasNext, index, photoItems, mediaByItem, onNavigate]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") {
        onClose();
        return;
      }
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        goPrev();
      }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        goNext();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose, goPrev, goNext]);

  if (!item) return null;

  const itemMedia = mediaByItem.get(item.id) ?? [];
  const { display, original, hasAnnotations, primary } = getPhotoMedia(itemMedia);
  const storedMediaId =
    lightbox.mediaId && itemMedia.some((m) => m.id === lightbox.mediaId) ? lightbox.mediaId : undefined;
  const displayId = storedMediaId ?? display?.id;
  const canAnnotate = !readOnly && primary != null;

  return (
    <div className={styles.lightbox} role="dialog" aria-modal="true" aria-label="Photo preview" onClick={onClose}>
      <div className={styles.lightboxInner} onClick={(e) => e.stopPropagation()}>
        <div className={styles.lightboxMedia}>
          <button type="button" className={styles.lightboxClose} onClick={onClose} aria-label="Close">
            ×
          </button>
          <button
            type="button"
            className={`${styles.lightboxNav} ${styles.lightboxNavPrev}`}
            onClick={goPrev}
            disabled={!hasPrev}
            aria-label="Previous photo"
          >
            ‹
          </button>
          <AnnotatedPhotoView
            key={`${item.id}-${displayId ?? "pending"}`}
            displayMediaId={displayId}
            originalMediaId={original?.id}
            alt={item.caption || "Job photo"}
          />
          <button
            type="button"
            className={`${styles.lightboxNav} ${styles.lightboxNavNext}`}
            onClick={goNext}
            disabled={!hasNext}
            aria-label="Next photo"
          >
            ›
          </button>
        </div>
        <div className={styles.lightboxFooter}>
          <LightboxCaption item={item} onSave={onSaveCaption} readOnly={readOnly} />
          <div className={styles.lightboxFooterBar}>
            <p className={styles.lightboxMeta}>
              {formatDate(item.captured_at)} · {formatTime(item.captured_at)}
              {photoItems.length > 1 && index >= 0 && (
                <> · {index + 1} of {photoItems.length}</>
              )}
            </p>
            <div className={styles.lightboxActions}>
              {original != null && (
                <span className={styles.lightboxPeekHint}>Hold photo to see original</span>
              )}
              {canAnnotate && (
                <button type="button" className={styles.annotateBtn} onClick={() => onAnnotate(item.id)}>
                  {hasAnnotations ? "Edit annotations" : "Annotate"}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function AnnotatedPhotoView({
  displayMediaId,
  originalMediaId,
  alt,
}: {
  displayMediaId?: string;
  originalMediaId?: string;
  alt: string;
}) {
  const [showOriginal, setShowOriginal] = useState(false);
  const [loadFailed, setLoadFailed] = useState(false);
  const [retryKey, setRetryKey] = useState(0);
  const canPeek = originalMediaId != null;
  const peeking = showOriginal && canPeek;
  const mediaId = peeking ? originalMediaId : displayMediaId;

  useEffect(() => {
    setLoadFailed(false);
  }, [mediaId, retryKey]);

  if (!mediaId) {
    return <p className={styles.mediaPending}>Photo pending upload…</p>;
  }

  const src = `${mediaDownloadUrl(mediaId)}${retryKey ? `&r=${retryKey}` : ""}`;

  return (
    <div className={styles.annotatedPhotoWrap}>
      {loadFailed ? (
        <div className={styles.lightboxLoadError}>
          <p>Couldn&apos;t load this photo.</p>
          <button type="button" onClick={() => setRetryKey((k) => k + 1)}>
            Retry
          </button>
        </div>
      ) : (
        /* eslint-disable-next-line @next/next/no-img-element */
        <img
          src={src}
          alt={alt}
          className={styles.lightboxImg}
          onError={() => setLoadFailed(true)}
          onPointerDown={canPeek ? () => setShowOriginal(true) : undefined}
          onPointerUp={canPeek ? () => setShowOriginal(false) : undefined}
          onPointerLeave={canPeek ? () => setShowOriginal(false) : undefined}
          onPointerCancel={canPeek ? () => setShowOriginal(false) : undefined}
        />
      )}
      {canPeek && peeking && !loadFailed && (
        <p className={styles.annotatedPhotoHint}>Showing original — release to return</p>
      )}
    </div>
  );
}

function LightboxCaption({
  item,
  onSave,
  readOnly = false,
}: {
  item: Item;
  onSave: (item: Item, caption: string) => Promise<void>;
  readOnly?: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(item.caption || "");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!editing) setValue(item.caption || "");
  }, [item.caption, editing]);

  async function commit() {
    try {
      await onSave(item, value);
      setEditing(false);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save");
    }
  }

  if (readOnly) {
    return item.caption ? <p className={styles.lightboxCaptionReadOnly}>{item.caption}</p> : null;
  }

  if (editing) {
    return (
      <div className={styles.lightboxCaptionEdit}>
        <textarea
          value={value}
          onChange={(e) => setValue(e.target.value)}
          maxLength={160}
          rows={2}
          autoFocus
          aria-label="Caption"
        />
        <div className={styles.lightboxCaptionEditActions}>
          <button type="button" onClick={() => setEditing(false)}>
            Cancel
          </button>
          <button type="button" onClick={commit}>
            Save
          </button>
        </div>
        {error && <span className={styles.error}>{error}</span>}
      </div>
    );
  }

  return (
    <button
      type="button"
      className={`${styles.lightboxCaptionField} ${item.caption ? "" : styles.lightboxCaptionFieldEmpty}`}
      onClick={() => setEditing(true)}
    >
      {item.caption || "Add a caption…"}
    </button>
  );
}

function VoiceIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
      <path d="M19 11v1a7 7 0 0 1-14 0v-1M12 18v3" />
    </svg>
  );
}

function NoteIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6M8 13h8M8 17h5" />
    </svg>
  );
}

function FileIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}

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

function groupByDate(items: Item[]) {
  return items.reduce<Record<string, Item[]>>((acc, item) => {
    const day = formatDayKey(item.captured_at);
    acc[day] ??= [];
    acc[day].push(item);
    return acc;
  }, {});
}

function JobSettingsIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
    </svg>
  );
}
