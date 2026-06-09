"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Item, ItemTag, Job, MediaFile, Tag } from "@/lib/api-jobs";
import {
  buildItemDeletePayload,
  buildJobDeletePayload,
  bulkItemDeleteCopy,
  jobDeleteCopy,
  singleItemDeleteCopy,
} from "@/lib/delete-helpers";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { ItemActionsMenu } from "@/components/item-actions-menu";
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
import { TimelineFilteredEmpty } from "@/components/timeline-search-panel";
import { TimelineTagFilterSheet } from "@/components/timeline-tag-filter-sheet";
import { MobileAddSheet } from "@/components/mobile-add-sheet";
import { DesktopAddMenu } from "@/components/desktop-add-menu";
import { AddNoteModal } from "@/components/add-note-modal";
import { ExportJobModal } from "@/components/export-job-modal";
import { DesktopTimelineToolbar } from "@/components/desktop-timeline-toolbar";
import { ExportIcon, LocationIcon, RefreshIcon } from "@/components/nav-icons";
import {
  MobileTimelineFilterSheet,
  type TimelineSortOrder,
} from "@/components/mobile-timeline-filter-sheet";
import {
  MobileDayTimeline,
  MobileSummaryChips,
  MobileTimelineToolbar,
} from "@/components/mobile-timeline";
import styles from "./job-detail.module.css";

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
  const pathname = usePathname();
  const [mobileChromeReady, setMobileChromeReady] = useState(false);
  const [job, setJob] = useState(initialJob);
  const isActiveJobRoute = pathname === `/jobs/${job.id}`;
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
  const [addMenuOpen, setAddMenuOpen] = useState(false);
  const [noteModalOpen, setNoteModalOpen] = useState(false);
  const [exportModalOpen, setExportModalOpen] = useState(false);
  const [desktopFilterOpen, setDesktopFilterOpen] = useState(false);
  const [mobileNoteOpen, setMobileNoteOpen] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [jobMenuOpen, setJobMenuOpen] = useState(false);
  const [editingNote, setEditingNote] = useState<Item | null>(null);
  const [mobileFilterOpen, setMobileFilterOpen] = useState(false);
  const [tagFilterOpen, setTagFilterOpen] = useState(false);
  const [workspaceTags, setWorkspaceTags] = useState<Tag[]>(initialTags);
  const mobileMenuRef = useRef<HTMLDivElement>(null);
  const jobMenuRef = useRef<HTMLDivElement>(null);
  const addMenuRef = useRef<HTMLDivElement>(null);
  const noteBodyRef = useRef<HTMLTextAreaElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const [tags, setTags] = useState(initialTags);
  const [itemTags, setItemTags] = useState(initialItemTags);
  const [selecting, setSelecting] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [deleting, setDeleting] = useState(false);
  const [confirmAction, setConfirmAction] = useState<
    { type: "items"; itemIds: string[] } | { type: "job" } | null
  >(null);

  const [query, setQuery] = useUrlQueryParam("q");
  const { values: kindFilter, toggle: toggleKind, setValues: setKindFilter } = useUrlSetParam("kind");
  const { values: tagFilter, toggle: toggleTag, setValues: setTagFilter } = useUrlSetParam("tag");
  const [dateFrom, setDateFrom] = useUrlQueryParam("from");
  const [dateTo, setDateTo] = useUrlQueryParam("to");
  const [sortOrder, setSortOrder] = useUrlQueryParam("sort");
  const timelineSort: TimelineSortOrder = sortOrder === "oldest" ? "oldest" : "newest";
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

  useEffect(() => {
    if (!jobMenuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (jobMenuRef.current && !jobMenuRef.current.contains(event.target as Node)) {
        setJobMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [jobMenuOpen]);

  useEffect(() => {
    setMobileChromeReady(true);
  }, []);

  useEffect(() => {
    if (!isActiveJobRoute) {
      setAddSheetOpen(false);
      setMobileFilterOpen(false);
      setTagFilterOpen(false);
    }
  }, [isActiveJobRoute]);

  useEffect(() => {
    if (!isActiveJobRoute || !selecting) {
      delete document.body.dataset.selectionMode;
      return;
    }
    document.body.dataset.selectionMode = "true";
    return () => {
      delete document.body.dataset.selectionMode;
    };
  }, [isActiveJobRoute, selecting]);

  useEffect(() => {
    if (!selecting) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") exitSelection();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [selecting]);

  useEffect(() => {
    if (!addMenuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (addMenuRef.current && !addMenuRef.current.contains(event.target as Node)) {
        setAddMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [addMenuOpen]);

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

      if ((delta.job as Job & { deleted_at?: string | null })?.deleted_at) {
        router.push("/jobs");
        return;
      }

      const merged = mergeJobBundle(
        itemsRef.current,
        mediaRef.current,
        delta,
        tagsRef.current,
        itemTagsRef.current,
      );
      if (merged.jobDeleted) {
        router.push("/jobs");
        return;
      }
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

  const filteredItems = useMemo(() => {
    let result = filterTimelineItems(
      items,
      mediaByItem,
      tagsByItem,
      query,
      kindFilter.size > 0 ? (kindFilter as ReadonlySet<ItemKind>) : undefined,
      tagFilter.size > 0 ? tagFilter : undefined,
    );
    if (dateFrom.trim()) {
      result = result.filter((item) => formatDayKey(item.captured_at) >= dateFrom.trim());
    }
    if (dateTo.trim()) {
      result = result.filter((item) => formatDayKey(item.captured_at) <= dateTo.trim());
    }
    return result;
  }, [items, mediaByItem, tagsByItem, query, kindFilter, tagFilter, dateFrom, dateTo]);

  const photoItems = useMemo(() => photoItemsInJob(filteredItems), [filteredItems]);

  const grouped = useMemo(() => groupByDate(filteredItems), [filteredItems]);
  const sortedDays = useMemo(() => {
    const entries = Object.entries(grouped).map(([dayKey, dayItems]) => {
      const sorted = [...dayItems].sort((a, b) => {
        const ta = new Date(a.captured_at).getTime();
        const tb = new Date(b.captured_at).getTime();
        return timelineSort === "oldest" ? ta - tb : tb - ta;
      });
      return [dayKey, sorted] as const;
    });
    return entries.sort(([a], [b]) =>
      timelineSort === "oldest" ? a.localeCompare(b) : b.localeCompare(a),
    );
  }, [grouped, timelineSort]);

  const hasActiveFilters =
    query.trim().length > 0 ||
    kindFilter.size > 0 ||
    tagFilter.size > 0 ||
    dateFrom.trim().length > 0 ||
    dateTo.trim().length > 0 ||
    timelineSort === "oldest";

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
    setDateFrom("");
    setDateTo("");
    setSortOrder("");
  }

  function selectKindChip(kind: ItemKind) {
    if (kindFilter.size === 1 && kindFilter.has(kind)) {
      setKindFilter(new Set());
      return;
    }
    setKindFilter(new Set([kind]));
  }

  function setTimelineSort(order: TimelineSortOrder) {
    setSortOrder(order === "newest" ? "" : order);
  }

  function applyTagFilter(next: Set<string>) {
    setTagFilter(next);
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
      setNoteModalOpen(false);
      setMobileNoteOpen(false);
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
    if (selecting) {
      setSelected((prev) => {
        const next = new Set(prev);
        if (next.has(itemId)) next.delete(itemId);
        else next.add(itemId);
        return next;
      });
      return;
    }
    setLightbox({ itemId, mediaId });
  }, [selecting]);

  function exitSelection() {
    setSelecting(false);
    setSelected(new Set());
  }

  function enterSelection(initialItemId?: string) {
    setSelecting(true);
    setSelected(initialItemId ? new Set([initialItemId]) : new Set());
  }

  function toggleSelected(itemId: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(itemId)) next.delete(itemId);
      else next.add(itemId);
      return next;
    });
  }

  function requestDeleteItems(itemIds: string[]) {
    if (itemIds.length === 0 || readOnly) return;
    setConfirmAction({ type: "items", itemIds });
  }

  function requestDeleteJob() {
    if (readOnly) return;
    setConfirmAction({ type: "job" });
    setMobileMenuOpen(false);
  }

  async function performDeleteItems(itemIds: string[]) {
    const idSet = new Set(itemIds);
    const snapshotItems = items.filter((item) => idSet.has(item.id));
    const snapshotMedia = mediaFiles.filter((media) => idSet.has(media.item_id));
    const snapshotItemTags = itemTags.filter((link) => idSet.has(link.item_id));

    setDeleting(true);
    setItems((prev) => prev.filter((item) => !idSet.has(item.id)));
    setMediaFiles((prev) => prev.filter((media) => !idSet.has(media.item_id)));
    setItemTags((prev) => prev.filter((link) => !idSet.has(link.item_id)));
    if (lightbox && idSet.has(lightbox.itemId)) setLightbox(null);
    exitSelection();

    try {
      await Promise.all(
        snapshotItems.map(async (item) => {
          const res = await fetch(`/api/jobs/${job.id}/items/${item.id}`, {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(buildItemDeletePayload(item)),
          });
          const data = await res.json();
          if (!res.ok) throw new Error(data.message || "Could not delete item");
        }),
      );
      setToast(
        snapshotItems.length === 1 ? "Item deleted" : `${snapshotItems.length} items deleted`,
      );
      router.refresh();
    } catch (err) {
      setItems((prev) =>
        [...snapshotItems, ...prev].sort(
          (a, b) => new Date(b.captured_at).getTime() - new Date(a.captured_at).getTime(),
        ),
      );
      setMediaFiles((prev) => [...prev, ...snapshotMedia]);
      setItemTags((prev) => [...prev, ...snapshotItemTags]);
      setToast(err instanceof Error ? err.message : "Could not delete items");
    } finally {
      setDeleting(false);
    }
  }

  async function performDeleteJob() {
    setDeleting(true);
    try {
      const res = await fetch(`/api/jobs/${job.id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(buildJobDeletePayload(job)),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || "Could not delete job");
      router.push("/jobs");
      router.refresh();
    } catch (err) {
      setToast(err instanceof Error ? err.message : "Could not delete job");
    } finally {
      setDeleting(false);
    }
  }

  async function handleConfirmDelete() {
    if (!confirmAction) return;
    if (confirmAction.type === "job") {
      setConfirmAction(null);
      await performDeleteJob();
      return;
    }
    const ids = confirmAction.itemIds;
    setConfirmAction(null);
    await performDeleteItems(ids);
  }

  function handleEditItem(itemId: string) {
    const item = items.find((entry) => entry.id === itemId);
    if (!item || readOnly) return;
    if (item.kind === "photo") {
      setLightbox({ itemId });
      return;
    }
    if (item.kind === "note") {
      setEditingNote(item);
      return;
    }
    setToast("Edit voice notes and files in the mobile app");
  }

  async function saveNoteEdit(item: Item, body: string, caption: string) {
    const now = new Date().toISOString();
    const res = await fetch(`/api/jobs/${job.id}/items/${item.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        kind: item.kind,
        body: body.trim(),
        caption: caption.trim() || null,
        captured_at: item.captured_at,
        created_at: item.created_at,
        updated_at: now,
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not save note");
    setItems((prev) => prev.map((entry) => (entry.id === item.id ? data : entry)));
    setEditingNote(null);
    router.refresh();
  }

  function handleToggleJobStatus() {
    setJobMenuOpen(false);
    setMobileMenuOpen(false);
    if (job.status === "completed") {
      void updateJobStatus("in_progress");
      return;
    }
    void updateJobStatus("completed");
  }

  function handleViewItem(itemId: string) {
    const item = items.find((entry) => entry.id === itemId);
    if (!item) return;
    if (item.kind === "photo") {
      openPhoto(itemId);
      return;
    }
    if (item.kind === "note") {
      setEditingNote(item);
    }
  }

  function handleShareItem() {
    setToast("Share is available in the mobile app");
  }

  function handleAnnotateItem(itemId: string) {
    setAnnotatingItemId(itemId);
  }

  function handleExportJob() {
    setJobMenuOpen(false);
    setMobileMenuOpen(false);
    setExportModalOpen(true);
  }

  function handleExportDownload() {
    setToast("Export is available in the mobile app");
  }

  function openDesktopNoteModal() {
    setNoteModalOpen(true);
    setNoteBody("");
    setNoteCaption("");
    setNoteMessage(null);
  }

  const confirmCopy = useMemo(() => {
    if (!confirmAction) return null;
    if (confirmAction.type === "job") return jobDeleteCopy(job.name);
    const ids = confirmAction.itemIds;
    if (ids.length === 1) {
      const item = items.find((entry) => entry.id === ids[0]);
      if (item) return singleItemDeleteCopy(item);
    }
    return bulkItemDeleteCopy(ids.length);
  }, [confirmAction, items, job.name]);

  function handleAnnotationSaved(itemId: string, updatedMedia: MediaFile[]) {
    setMediaFiles((prev) => {
      const rest = prev.filter((m) => m.item_id !== itemId);
      return [...rest, ...updatedMedia];
    });
    router.refresh();
  }

  const annotatingItem = annotatingItemId ? items.find((i) => i.id === annotatingItemId) : null;
  const subtitle = [job.client_name, job.address].filter(Boolean).join(" · ");
  const hasExtraDetails = Boolean(job.job_number || job.start_date || job.end_date || job.notes);

  function openMobileNoteCompose() {
    setMobileNoteOpen(true);
    window.requestAnimationFrame(() => noteBodyRef.current?.focus());
  }

  const showMobileAddFab =
    mobileChromeReady && isActiveJobRoute && !readOnly && !selecting && items.length > 0;

  return (
    <div className={styles.jobDetailRoot}>
    <div className={`${styles.mobileJobDetail} mobileOnly`}>
    <header className={styles.mobileDetailHeader}>
      {selecting ? (
        <div className={styles.mobileSelectionHeader}>
          <button type="button" className={styles.mobileSelectionCancel} onClick={exitSelection}>
            Cancel
          </button>
          <span className={styles.mobileSelectionCount}>
            {selected.size === 0 ? "Select items" : `${selected.size} selected`}
          </span>
        </div>
      ) : (
        <>
          <div className={styles.mobileTopRow}>
            <Link href="/jobs" className={styles.mobileBack} aria-label="Back to jobs">
              ←
            </Link>
            <h1 className={styles.mobileDetailTitle}>{job.name}</h1>
            {!readOnly && (
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
                    <button type="button" onClick={() => { setEditOpen(true); setMobileMenuOpen(false); }}>
                      Edit job
                    </button>
                    <button type="button" onClick={handleExportJob}>
                      Export job
                    </button>
                    <button type="button" onClick={() => { enterSelection(); setMobileMenuOpen(false); }}>
                      Select items
                    </button>
                    <button type="button" onClick={handleToggleJobStatus}>
                      {job.status === "completed" ? "Reopen job" : "Mark completed"}
                    </button>
                    <hr />
                    <button type="button" className={styles.mobileMenuDanger} onClick={requestDeleteJob}>
                      Delete job
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
          {job.address && (
            <p className={styles.mobileDetailLocation}>
              <LocationIcon />
              {job.address}
            </p>
          )}
          {job.client_name && !job.address && (
            <p className={styles.mobileDetailLocation}>{job.client_name}</p>
          )}
          {job.client_name && job.address && (
            <p className={styles.mobileDetailClient}>{job.client_name}</p>
          )}
          <span className={`${styles.mobileDetailStatus} ${styles[`status_${job.status}`]}`}>
            {job.status === "completed" && <span aria-hidden>✓ </span>}
            {job.status === "completed"
              ? "Completed"
              : job.status === "in_progress"
                ? "In progress"
                : "Planning"}
          </span>
        </>
      )}
      {!selecting && items.length > 0 && (
        <MobileSummaryChips
          totalCount={items.length}
          counts={kindCounts}
          kindFilter={kindFilter as ReadonlySet<ItemKind>}
          onSelectAll={() => setKindFilter(new Set())}
          onSelectKind={selectKindChip}
        />
      )}
      {!selecting && items.length > 0 && (
        <MobileTimelineToolbar
          query={query}
          onQueryChange={setQuery}
          onOpenFilters={() => setMobileFilterOpen(true)}
          hasFilters={hasActiveFilters}
          inputRef={searchRef}
        />
      )}
      {!selecting && items.length > 0 && hasActiveFilters && (
        <button
          type="button"
          className={styles.mobileFilterSummary}
          onClick={() => setMobileFilterOpen(true)}
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

    {showMobileAddFab && (
      <button
        type="button"
        className={styles.mobileAddFab}
        onClick={() => setAddSheetOpen(true)}
        aria-label="Add to job"
      >
        + Add to job
      </button>
    )}

    {mobileChromeReady && isActiveJobRoute && selecting && !readOnly && (
      <div className={styles.mobileSelectionBar}>
        <div className={styles.selectionBarActions}>
          <button
            type="button"
            className={styles.selectionOutlineBtn}
            onClick={() => setToast("Tag assignment is available in the mobile app")}
            disabled={selected.size === 0}
          >
            Tag
          </button>
          <button
            type="button"
            className={styles.selectionOutlineBtn}
            onClick={() => setToast("Export is available in the mobile app")}
            disabled={selected.size === 0}
          >
            Export
          </button>
          <button
            type="button"
            className={styles.selectionDeleteSolid}
            disabled={deleting || selected.size === 0}
            onClick={() => requestDeleteItems([...selected])}
          >
            {deleting ? "Deleting…" : "Delete"}
          </button>
        </div>
      </div>
    )}
    </div>

    <PageShell
      className={`${styles.detailShell} ${selecting ? styles.detailShellSelecting : ""}`}
      headerClassName={`${styles.pageShellHeaderHidden} desktopOnly`}
      title={job.name}
      subtitle={subtitle || "Job timeline"}
    >
      <header className={`${styles.desktopJobHeader} desktopOnly`}>
        {selecting ? (
          <div className={styles.desktopSelectionHeader}>
            <span className={styles.desktopSelectionCount}>
              {selected.size === 0 ? "Select items" : `${selected.size} selected`}
            </span>
            <div className={styles.desktopSelectionActions}>
              <button
                type="button"
                className={styles.selectionOutlineBtn}
                onClick={() => setToast("Tag assignment is available in the mobile app")}
                disabled={selected.size === 0}
              >
                Tag
              </button>
              <button
                type="button"
                className={styles.selectionOutlineBtn}
                onClick={() => {
                  setExportModalOpen(true);
                }}
                disabled={selected.size === 0}
              >
                Export
              </button>
              <button
                type="button"
                className={styles.selectionDeleteSolid}
                disabled={deleting || selected.size === 0}
                onClick={() => requestDeleteItems([...selected])}
              >
                {deleting ? "Deleting…" : "Delete"}
              </button>
              <button type="button" className={styles.desktopSelectionCancel} onClick={exitSelection}>
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <>
            <div className={styles.desktopHeaderRow}>
              <div className={styles.desktopHeaderInfo}>
                <h1 className={styles.desktopJobTitle}>{job.name}</h1>
                {job.address && (
                  <p className={styles.desktopJobAddress}>
                    <LocationIcon />
                    {job.address}
                  </p>
                )}
                {job.client_name && !job.address && (
                  <p className={styles.desktopJobAddress}>{job.client_name}</p>
                )}
                <div className={styles.statusPicker} ref={statusMenuRef}>
                  {readOnly ? (
                    <span className={`${styles.desktopStatusPill} ${styles[`status_${job.status}`]}`}>
                      {job.status === "completed" && <span aria-hidden>✓ </span>}
                      {job.status === "completed"
                        ? "Completed"
                        : job.status === "in_progress"
                          ? "In progress"
                          : "Planning"}
                    </span>
                  ) : (
                    <button
                      type="button"
                      className={`${styles.desktopStatusPill} ${styles.statusPillBtn} ${styles[`status_${job.status}`]}`}
                      onClick={() => setStatusMenuOpen((open) => !open)}
                      disabled={updatingStatus}
                      aria-haspopup="listbox"
                      aria-expanded={statusMenuOpen}
                    >
                      {job.status === "completed" && <span aria-hidden>✓ </span>}
                      {job.status === "completed"
                        ? "Completed"
                        : job.status === "in_progress"
                          ? "In progress"
                          : "Planning"}
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
              </div>
              <div className={styles.desktopHeaderActions}>
                <button
                  type="button"
                  className={styles.desktopGhostBtn}
                  onClick={refresh}
                  disabled={refreshing}
                >
                  <RefreshIcon />
                  {refreshing ? "Refreshing…" : "Refresh"}
                </button>
                <button type="button" className={styles.desktopGhostBtn} onClick={handleExportJob}>
                  <ExportIcon />
                  Export
                </button>
                {!readOnly && (
                  <div className={styles.jobMenuWrap} ref={jobMenuRef}>
                    <button
                      type="button"
                      className={styles.desktopGhostBtnIcon}
                      onClick={() => setJobMenuOpen((open) => !open)}
                      aria-expanded={jobMenuOpen}
                      aria-label="Job actions"
                    >
                      ⋮
                    </button>
                    {jobMenuOpen && (
                      <div className={styles.jobMenuDropdown}>
                        <button type="button" onClick={() => { setEditOpen(true); setJobMenuOpen(false); }}>
                          Edit job
                        </button>
                        <button type="button" onClick={handleExportJob}>
                          Export job
                        </button>
                        <button type="button" onClick={handleToggleJobStatus}>
                          {job.status === "completed" ? "Reopen job" : "Mark completed"}
                        </button>
                        <button type="button" className={styles.jobMenuDanger} onClick={requestDeleteJob}>
                          Delete job
                        </button>
                      </div>
                    )}
                  </div>
                )}
                {!readOnly && (
                  <div className={styles.addToJobWrap} ref={addMenuRef}>
                    <button
                      type="button"
                      className={styles.addToJobBtn}
                      onClick={() => setAddMenuOpen((open) => !open)}
                      aria-expanded={addMenuOpen}
                      aria-haspopup="menu"
                    >
                      + Add to job
                    </button>
                    <DesktopAddMenu
                      open={addMenuOpen}
                      onClose={() => setAddMenuOpen(false)}
                      onAddNote={openDesktopNoteModal}
                    />
                  </div>
                )}
              </div>
            </div>

            {hasExtraDetails && (
              <details className={styles.jobDetailsCollapsible}>
                <summary>Job details</summary>
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
              </details>
            )}

            {items.length > 0 && (
              <>
                <MobileSummaryChips
                  totalCount={items.length}
                  counts={kindCounts}
                  kindFilter={kindFilter as ReadonlySet<ItemKind>}
                  onSelectAll={() => setKindFilter(new Set())}
                  onSelectKind={selectKindChip}
                />
                <DesktopTimelineToolbar
                  query={query}
                  onQueryChange={setQuery}
                  onOpenFilters={() => setDesktopFilterOpen(true)}
                  hasFilters={hasActiveFilters}
                  selecting={selecting}
                  onSelectToggle={() => (selecting ? exitSelection() : enterSelection())}
                  readOnly={readOnly}
                  inputRef={searchRef}
                />
                {hasActiveFilters && (
                  <button
                    type="button"
                    className={styles.desktopFilterSummary}
                    onClick={() => setDesktopFilterOpen(true)}
                  >
                    <span>{activeFilterSummary}</span>
                    <span
                      className={styles.desktopFilterSummaryClear}
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
              </>
            )}
          </>
        )}
      </header>
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
      <section
        className={`${mobileNoteOpen ? `${styles.compose} ${styles.composeMobileOpen}` : styles.compose} mobileOnly`}
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
        <div className={`${styles.mobileEmptyState} mobileOnly`}>
          <h2>No records yet</h2>
          <p>Add photos, notes, voice notes, or files to build a job timeline.</p>
          {!readOnly && (
            <button type="button" className={styles.mobileEmptyCta} onClick={() => setAddSheetOpen(true)}>
              + Add to job
            </button>
          )}
        </div>
      ) : null}

      {items.length === 0 ? (
        <div className={`${styles.desktopEmptyState} desktopOnly`}>
          <h2>No records yet</h2>
          <p>Add photos, notes, voice notes, or files to build a job timeline.</p>
          {!readOnly && (
            <button type="button" className={styles.addToJobBtn} onClick={() => setAddMenuOpen(true)}>
              + Add to job
            </button>
          )}
        </div>
      ) : (
        <>
          {filteredItems.length === 0 ? (
            <TimelineFilteredEmpty onClear={clearFilters} />
          ) : (
            sortedDays.map(([dayKey, dayItems]) => (
              <div key={dayKey}>
                <div className="mobileOnly">
                  <MobileDayTimeline
                    variant="mobile"
                    dayKey={dayKey}
                    items={dayItems}
                    mediaByItem={mediaByItem}
                    tagsByItem={tagsByItem}
                    onOpenPhoto={openPhoto}
                    onToggleTag={toggleTag}
                    tagFilter={tagFilter}
                    selecting={selecting}
                    selected={selected}
                    onToggleSelect={toggleSelected}
                    onLongPressSelect={enterSelection}
                    onDeleteItem={(itemId) => requestDeleteItems([itemId])}
                    onEditItem={handleEditItem}
                    onViewItem={handleViewItem}
                    onShareItem={handleShareItem}
                    onAnnotateItem={handleAnnotateItem}
                    readOnly={readOnly}
                  />
                </div>
                <div className="desktopOnly">
                  <MobileDayTimeline
                    variant="desktop"
                    dayKey={dayKey}
                    items={dayItems}
                    mediaByItem={mediaByItem}
                    tagsByItem={tagsByItem}
                    onOpenPhoto={openPhoto}
                    onToggleTag={toggleTag}
                    tagFilter={tagFilter}
                    selecting={selecting}
                    selected={selected}
                    onToggleSelect={toggleSelected}
                    onDeleteItem={(itemId) => requestDeleteItems([itemId])}
                    onEditItem={handleEditItem}
                    onViewItem={handleViewItem}
                    onShareItem={handleShareItem}
                    onAnnotateItem={handleAnnotateItem}
                    readOnly={readOnly}
                  />
                </div>
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
          onDelete={(itemId) => requestDeleteItems([itemId])}
          onEdit={(itemId) => handleEditItem(itemId)}
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


    <ConfirmDialog
      open={confirmAction != null && confirmCopy != null}
      title={confirmCopy?.title ?? ""}
      message={confirmCopy?.message ?? ""}
      confirmLabel={confirmCopy?.confirmLabel}
      busy={deleting}
      onConfirm={handleConfirmDelete}
      onCancel={() => setConfirmAction(null)}
    />

    {editingNote && (
      <NoteEditModal
        item={editingNote}
        onClose={() => setEditingNote(null)}
        onSave={saveNoteEdit}
      />
    )}

    <MobileAddSheet
      open={addSheetOpen && isActiveJobRoute}
      onClose={() => setAddSheetOpen(false)}
      jobName={job.name}
      readOnly={readOnly}
      onAddNote={openMobileNoteCompose}
    />

    <AddNoteModal
      open={noteModalOpen}
      onClose={() => setNoteModalOpen(false)}
      caption={noteCaption}
      body={noteBody}
      onCaptionChange={setNoteCaption}
      onBodyChange={setNoteBody}
      onSave={addNote}
      saving={saving}
      error={noteMessage && noteMessage !== "Saved" ? noteMessage : null}
    />

    <ExportJobModal
      open={exportModalOpen}
      onClose={() => setExportModalOpen(false)}
      jobName={job.name}
      items={items}
      initialSelectedIds={selecting && selected.size > 0 ? selected : undefined}
      onExport={handleExportDownload}
    />

    <MobileTimelineFilterSheet
      open={(mobileFilterOpen || desktopFilterOpen) && isActiveJobRoute}
      onClose={() => {
        setMobileFilterOpen(false);
        setDesktopFilterOpen(false);
      }}
      kindFilter={kindFilter as ReadonlySet<ItemKind>}
      onToggleKind={(kind) => toggleKind(kind)}
      onClearKinds={() => setKindFilter(new Set())}
      allTags={allTags}
      tagsInJob={tagsInJob}
      tagFilter={tagFilter}
      onToggleTag={toggleTag}
      onClearTags={() => setTagFilter(new Set())}
      dateFrom={dateFrom}
      dateTo={dateTo}
      onDateFromChange={setDateFrom}
      onDateToChange={setDateTo}
      sortOrder={timelineSort}
      onSortOrderChange={setTimelineSort}
      onClearAll={clearFilters}
      hasActiveFilters={hasActiveFilters}
    />

    <TimelineTagFilterSheet
      open={tagFilterOpen}
      onClose={() => setTagFilterOpen(false)}
      allTags={allTags}
      tagsInJob={tagsInJob}
      selectedTagIds={tagFilter}
      onApply={applyTagFilter}
    />
    </div>
  );
}

function jobCursorValue(lastActivityAt: string, updatedAt: string): string {
  return new Date(updatedAt) > new Date(lastActivityAt) ? updatedAt : lastActivityAt;
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
  onDelete,
  onEdit,
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
  onDelete?: (itemId: string) => void;
  onEdit?: (itemId: string) => void;
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
              {!readOnly && onDelete && (
                <ItemActionsMenu
                  onEdit={onEdit ? () => onEdit(item.id) : undefined}
                  onDelete={() => onDelete(item.id)}
                />
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

function NoteEditModal({
  item,
  onClose,
  onSave,
}: {
  item: Item;
  onClose: () => void;
  onSave: (item: Item, body: string, caption: string) => Promise<void>;
}) {
  const [body, setBody] = useState(item.body ?? "");
  const [caption, setCaption] = useState(item.caption ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape" && !saving) onClose();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onClose, saving]);

  async function handleSave() {
    setSaving(true);
    setError(null);
    try {
      await onSave(item, body, caption);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save note");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className={styles.noteEditBackdrop} role="presentation" onClick={saving ? undefined : onClose}>
      <div
        className={styles.noteEditDialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby="note-edit-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="note-edit-title">Edit note</h2>
        <label className={styles.noteEditLabel}>
          Caption (optional)
          <input value={caption} onChange={(e) => setCaption(e.target.value)} maxLength={160} />
        </label>
        <label className={styles.noteEditLabel}>
          Note
          <textarea value={body} onChange={(e) => setBody(e.target.value)} rows={6} />
        </label>
        {error && <p className={styles.error}>{error}</p>}
        <div className={styles.noteEditActions}>
          <button type="button" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button type="button" className={styles.primary} onClick={handleSave} disabled={saving || !body.trim()}>
            {saving ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
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

