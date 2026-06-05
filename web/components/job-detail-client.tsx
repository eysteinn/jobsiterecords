"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Item, Job, MediaFile } from "@/lib/api-jobs";
import { useSyncPoll } from "@/hooks/use-sync-poll";
import { formatDate, formatDayKey, formatTime } from "@/lib/format";
import { fetchJobDelta, mergeJobBundle, pollJobCursor } from "@/lib/sync-cursor";
import { SYNC_POLL } from "@/lib/sync-poll-config";
import { getPhotoMedia, itemThumbUrl, mediaDownloadUrl } from "@/lib/photo-media";
import { PhotoAnnotationEditor } from "@/components/photo-annotation/photo-annotation-editor";
import { PageShell } from "@/components/page-shell";
import styles from "./job-detail.module.css";

type Props = {
  job: Job;
  items: Item[];
  mediaFiles: MediaFile[];
  workspaceId: string;
  readOnly?: boolean;
};

type TimelineSegment =
  | { type: "photos"; items: Item[] }
  | { type: "row"; item: Item };

export function JobDetailClient({ job, items: initialItems, mediaFiles: initialMediaFiles, readOnly = false }: Props) {
  const router = useRouter();
  const [items, setItems] = useState(initialItems ?? []);
  const [mediaFiles, setMediaFiles] = useState(initialMediaFiles ?? []);
  const [noteBody, setNoteBody] = useState("");
  const [noteCaption, setNoteCaption] = useState("");
  const [saving, setSaving] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [fieldUpdateBanner, setFieldUpdateBanner] = useState(false);
  const [lightbox, setLightbox] = useState<{ itemId: string; mediaId?: string } | null>(null);
  const [annotatingItemId, setAnnotatingItemId] = useState<string | null>(null);
  const cursorRef = useRef(job.last_activity_at ?? job.updated_at);
  const itemsRef = useRef(items);
  const mediaRef = useRef(mediaFiles);
  itemsRef.current = items;
  mediaRef.current = mediaFiles;

  useEffect(() => {
    setItems(initialItems ?? []);
  }, [initialItems]);

  useEffect(() => {
    setMediaFiles(initialMediaFiles ?? []);
  }, [initialMediaFiles]);

  useEffect(() => {
    cursorRef.current = job.last_activity_at ?? job.updated_at;
  }, [job.last_activity_at, job.updated_at]);

  const onJobChanged = useCallback(
    async (result: { cursor: string | null }) => {
      const since = cursorRef.current;
      const nextCursor = result.cursor ?? since;
      const delta = await fetchJobDelta(job.id, since);
      const hasDelta =
        (delta.items?.length ?? 0) > 0 || (delta.media_files?.length ?? 0) > 0;

      // Cursor moved but delta missed rows (timestamp boundary / clock skew) — full reload.
      if (!hasDelta && nextCursor !== since) {
        cursorRef.current = nextCursor;
        router.refresh();
        return;
      }

      const merged = mergeJobBundle(itemsRef.current, mediaRef.current, delta);
      if (merged.added > 0) {
        setItems(merged.items);
        setMediaFiles(merged.mediaFiles);
        setFieldUpdateBanner(true);
        window.setTimeout(() => setFieldUpdateBanner(false), SYNC_POLL.updatedBannerMs);
      } else if (hasDelta) {
        setItems(merged.items);
        setMediaFiles(merged.mediaFiles);
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

  const photoItems = useMemo(() => photoItemsInJob(items), [items]);

  const grouped = useMemo(() => groupByDate(items), [items]);
  const sortedDays = useMemo(
    () => Object.entries(grouped).sort(([a], [b]) => b.localeCompare(a)),
    [grouped],
  );

  async function addNote() {
    if (!noteBody.trim()) return;
    setSaving(true);
    setMessage(null);
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
      setMessage("Saved");
      router.refresh();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Could not save");
    } finally {
      setSaving(false);
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

  return (
    <PageShell
      title={job.name}
      subtitle={[job.client_name, job.address].filter(Boolean).join(" · ") || "Job timeline"}
      action={
        <div className={styles.headerActions}>
          <button type="button" className={styles.refreshBtn} onClick={refresh} disabled={refreshing}>
            {refreshing ? "Refreshing…" : "Refresh"}
          </button>
          <Link href="/jobs" className={styles.backLink}>
            ← All jobs
          </Link>
        </div>
      }
    >
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
      <section className={styles.compose}>
        <h2>Add text note</h2>
        <input
          placeholder="Caption (optional)"
          value={noteCaption}
          onChange={(e) => setNoteCaption(e.target.value)}
        />
        <textarea
          placeholder="Note body"
          rows={3}
          value={noteBody}
          onChange={(e) => setNoteBody(e.target.value)}
        />
        <div className={styles.composeActions}>
          <button type="button" className={styles.primary} disabled={saving} onClick={addNote}>
            {saving ? "Saving…" : "Add note"}
          </button>
          {message && <span className={styles.saved}>{message}</span>}
        </div>
      </section>
      )}

      {items.length === 0 ? (
        <p className={styles.empty}>No timeline items yet.</p>
      ) : (
        sortedDays.map(([dayKey, dayItems]) => (
          <section key={dayKey} className={styles.dayGroup}>
            <h3>{formatDate(`${dayKey}T12:00:00.000Z`)}</h3>
            <div className={styles.dayContent}>
              {segmentDayItems(dayItems).map((seg, i) =>
                seg.type === "photos" ? (
                  <PhotoGrid
                    key={`g-${dayKey}-${i}`}
                    items={seg.items}
                    mediaByItem={mediaByItem}
                    onOpen={openPhoto}
                  />
                ) : (
                  <ul key={`r-${seg.item.id}`} className={styles.timelineRows}>
                    <li>
                      <TimelineRow item={seg.item} media={mediaByItem.get(seg.item.id) ?? []} />
                    </li>
                  </ul>
                ),
              )}
            </div>
          </section>
        ))
      )}

      {lightbox && (
        <PhotoLightbox
          items={items}
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
    </PageShell>
  );
}

function PhotoGrid({
  items,
  mediaByItem,
  onOpen,
}: {
  items: Item[];
  mediaByItem: Map<string, MediaFile[]>;
  onOpen: (itemId: string, mediaId?: string) => void;
}) {
  return (
    <div className={styles.photoGrid} role="group" aria-label="Photos">
      {items.map((item) => (
        <PhotoCell
          key={item.id}
          item={item}
          media={mediaByItem.get(item.id) ?? []}
          onOpen={onOpen}
        />
      ))}
    </div>
  );
}

function PhotoCell({
  item,
  media,
  onOpen,
}: {
  item: Item;
  media: MediaFile[];
  onOpen: (itemId: string, mediaId?: string) => void;
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
  );
}

function TimelineRow({ item, media }: { item: Item; media: MediaFile[] }) {
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
  const displayId = lightbox.mediaId ?? display?.id;
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
  const canPeek = originalMediaId != null;
  const peeking = showOriginal && canPeek;
  const mediaId = peeking ? originalMediaId : displayMediaId;

  if (!mediaId) {
    return <p className={styles.mediaPending}>Photo pending upload…</p>;
  }

  return (
    <div className={styles.annotatedPhotoWrap}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={mediaDownloadUrl(mediaId)}
        alt={alt}
        className={styles.lightboxImg}
        onPointerDown={canPeek ? () => setShowOriginal(true) : undefined}
        onPointerUp={canPeek ? () => setShowOriginal(false) : undefined}
        onPointerLeave={canPeek ? () => setShowOriginal(false) : undefined}
        onPointerCancel={canPeek ? () => setShowOriginal(false) : undefined}
      />
      {canPeek && peeking && (
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
