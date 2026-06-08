"use client";

import { useEffect, useRef, useState } from "react";
import type { Item, MediaFile, Tag } from "@/lib/api-jobs";
import { formatDayHeading, formatDuration, formatFileSize, formatTime } from "@/lib/format";
import { getPhotoMedia, itemThumbUrl } from "@/lib/photo-media";
import { quickTagsForJob, type ItemKind } from "@/lib/search";
import styles from "./mobile-timeline.module.css";

type KindCounts = Record<ItemKind, number>;

type SummaryChipsProps = {
  counts: KindCounts;
  kindFilter: ReadonlySet<ItemKind>;
  onToggleKind: (kind: ItemKind) => void;
};

const KIND_META: { kind: ItemKind; label: string; icon: string }[] = [
  { kind: "photo", label: "Photos", icon: "🖼" },
  { kind: "note", label: "Notes", icon: "📝" },
  { kind: "voice", label: "Voice", icon: "🎙" },
  { kind: "file", label: "Files", icon: "📄" },
];

export function MobileSummaryChips({ counts, kindFilter, onToggleKind }: SummaryChipsProps) {
  return (
    <div className={styles.summaryRow} role="group" aria-label="Filter by item type">
      {KIND_META.map(({ kind, label, icon }) => {
        const count = counts[kind];
        if (count === 0) return null;
        const active = kindFilter.has(kind);
        return (
          <button
            key={kind}
            type="button"
            className={active ? styles.summaryChipActive : styles.summaryChip}
            aria-pressed={active}
            onClick={() => onToggleKind(kind)}
          >
            <span aria-hidden>{icon}</span>
            {label} {count}
          </button>
        );
      })}
    </div>
  );
}

type ToolbarProps = {
  query: string;
  onQueryChange: (value: string) => void;
  onOpenFilters: () => void;
  onOpenTagFilter: () => void;
  hasFilters: boolean;
  hasTagFilter: boolean;
  inputRef?: React.RefObject<HTMLInputElement | null>;
  selecting?: boolean;
  onSelectToggle?: () => void;
  readOnly?: boolean;
};

export function MobileTimelineToolbar({
  query,
  onQueryChange,
  onOpenFilters,
  onOpenTagFilter,
  hasFilters,
  hasTagFilter,
  inputRef,
  selecting = false,
  onSelectToggle,
  readOnly = false,
}: ToolbarProps) {
  return (
    <div className={styles.toolbar}>
      <div className={styles.searchWrap}>
        <span className={styles.searchIcon} aria-hidden>
          🔍
        </span>
        <input
          ref={inputRef}
          type="search"
          className={styles.searchInput}
          placeholder="Search captions, notes, tags…"
          value={query}
          onChange={(e) => onQueryChange(e.target.value)}
          aria-label="Search timeline"
        />
        {query && (
          <button
            type="button"
            className={styles.clearBtn}
            onClick={() => onQueryChange("")}
            aria-label="Clear search"
          >
            ×
          </button>
        )}
      </div>
      <button
        type="button"
        className={`${styles.filterBtn} ${hasTagFilter ? styles.filterBtnActive : ""}`}
        onClick={onOpenTagFilter}
        aria-label="Filter by tag"
      >
        <TagIcon />
        {hasTagFilter && <span className={styles.filterDot} aria-hidden />}
      </button>
      <button
        type="button"
        className={`${styles.filterBtn} ${hasFilters && !hasTagFilter ? styles.filterBtnActive : ""}`}
        onClick={onOpenFilters}
        aria-label="Filter by type"
      >
        <span aria-hidden>☰</span>
        {hasFilters && !hasTagFilter && <span className={styles.filterDot} aria-hidden />}
      </button>
      {!readOnly && onSelectToggle && (
        <button
          type="button"
          className={selecting ? `${styles.selectBtn} ${styles.selectBtnActive}` : styles.selectBtn}
          onClick={onSelectToggle}
          aria-pressed={selecting}
        >
          {selecting ? "Cancel" : "Select"}
        </button>
      )}
    </div>
  );
}

type QuickTagRowProps = {
  allTags: Tag[];
  tagsInJob: ReadonlySet<string>;
  tagFilter: ReadonlySet<string>;
  onToggleTag: (tagId: string) => void;
  onOpenTagFilter: () => void;
};

export function MobileQuickTagRow({
  allTags,
  tagsInJob,
  tagFilter,
  onToggleTag,
  onOpenTagFilter,
}: QuickTagRowProps) {
  const quickTags = quickTagsForJob(allTags, tagsInJob);
  const moreTagCount = Math.max(0, tagsInJob.size - quickTags.length);
  if (quickTags.length === 0 && tagFilter.size === 0 && allTags.length === 0) return null;

  return (
    <div className={styles.quickTagRow} role="group" aria-label="Filter by tag">
      <button
        type="button"
        className={`${styles.quickTagChip} ${tagFilter.size > 0 ? styles.quickTagChipActive : ""}`}
        onClick={onOpenTagFilter}
      >
        {tagFilter.size === 0 ? "Tags" : `Tags (${tagFilter.size})`}
      </button>
      {quickTags.map((tag) => {
        const active = tagFilter.has(tag.id);
        return (
          <button
            key={tag.id}
            type="button"
            className={active ? styles.quickTagChipActive : styles.quickTagChip}
            aria-pressed={active}
            onClick={() => onToggleTag(tag.id)}
          >
            {tag.name}
          </button>
        );
      })}
      {moreTagCount > 0 && (
        <button type="button" className={styles.quickTagMore} onClick={onOpenTagFilter}>
          +{moreTagCount} more
        </button>
      )}
    </div>
  );
}

type DayTimelineProps = {
  dayKey: string;
  items: Item[];
  mediaByItem: Map<string, MediaFile[]>;
  tagsByItem: Map<string, Tag[]>;
  onOpenPhoto: (itemId: string, mediaId?: string) => void;
  onToggleTag?: (tagId: string) => void;
  tagFilter?: ReadonlySet<string>;
  selecting?: boolean;
  selected?: Set<string>;
  onToggleSelect?: (itemId: string) => void;
  onLongPressSelect?: (itemId: string) => void;
  onDeleteItem?: (itemId: string) => void;
  onEditItem?: (itemId: string) => void;
  readOnly?: boolean;
};

export function MobileDayTimeline({
  dayKey,
  items,
  mediaByItem,
  tagsByItem,
  onOpenPhoto,
  onToggleTag,
  tagFilter,
  selecting = false,
  selected,
  onToggleSelect,
  onLongPressSelect,
  onDeleteItem,
  onEditItem,
  readOnly = false,
}: DayTimelineProps) {
  return (
    <section className={styles.daySection}>
      <h3 className={styles.dayHeading}>{formatDayHeading(dayKey)}</h3>
      <ol className={styles.timelineList}>
        {items.map((item) => (
          <li key={item.id} className={styles.timelineItem}>
            <MobileTimelineCard
              item={item}
              media={mediaByItem.get(item.id) ?? []}
              tags={tagsByItem.get(item.id) ?? []}
              onOpenPhoto={onOpenPhoto}
              onToggleTag={onToggleTag}
              tagFilter={tagFilter}
              selecting={selecting}
              isSelected={selected?.has(item.id) ?? false}
              onToggleSelect={onToggleSelect}
              onLongPressSelect={onLongPressSelect}
              onDeleteItem={onDeleteItem}
              onEditItem={onEditItem}
              readOnly={readOnly}
            />
          </li>
        ))}
      </ol>
    </section>
  );
}

type CardProps = {
  item: Item;
  media: MediaFile[];
  tags: Tag[];
  onOpenPhoto: (itemId: string, mediaId?: string) => void;
  onToggleTag?: (tagId: string) => void;
  tagFilter?: ReadonlySet<string>;
  selecting?: boolean;
  isSelected?: boolean;
  onToggleSelect?: (itemId: string) => void;
  onLongPressSelect?: (itemId: string) => void;
  onDeleteItem?: (itemId: string) => void;
  onEditItem?: (itemId: string) => void;
  readOnly?: boolean;
};

function MobileTimelineCard({
  item,
  media,
  tags,
  onOpenPhoto,
  onToggleTag,
  tagFilter,
  selecting = false,
  isSelected = false,
  onToggleSelect,
  onLongPressSelect,
  onDeleteItem,
  onEditItem,
  readOnly = false,
}: CardProps) {
  const time = formatTime(item.captured_at);
  const kindLabel = item.kind === "voice" ? "Voice note" : item.kind.charAt(0).toUpperCase() + item.kind.slice(1);
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const longPressRef = useRef<number | null>(null);

  useEffect(() => {
    if (!menuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [menuOpen]);

  function clearLongPress() {
    if (longPressRef.current != null) {
      window.clearTimeout(longPressRef.current);
      longPressRef.current = null;
    }
  }

  function handlePointerDown() {
    if (readOnly || selecting || !onLongPressSelect) return;
    clearLongPress();
    longPressRef.current = window.setTimeout(() => {
      onLongPressSelect(item.id);
      longPressRef.current = null;
    }, 500);
  }

  return (
    <article
      className={`${styles.card} ${selecting ? styles.cardSelecting : ""} ${isSelected ? styles.cardSelected : ""}`}
      onPointerDown={handlePointerDown}
      onPointerUp={clearLongPress}
      onPointerLeave={clearLongPress}
      onPointerCancel={clearLongPress}
    >
      {selecting ? (
        <input
          type="checkbox"
          className={styles.cardCheckbox}
          checked={isSelected}
          onChange={() => onToggleSelect?.(item.id)}
          aria-label={`Select ${kindLabel}`}
        />
      ) : (
        !readOnly &&
        onDeleteItem && (
          <div className={styles.cardMenuWrap} ref={menuRef}>
            <button
              type="button"
              className={styles.cardMenu}
              aria-label="More options"
              aria-expanded={menuOpen}
              onClick={() => setMenuOpen((open) => !open)}
            >
              ⋮
            </button>
            {menuOpen && (
              <div className={styles.cardMenuDropdown}>
                {onEditItem && (
                  <button
                    type="button"
                    onClick={() => {
                      onEditItem(item.id);
                      setMenuOpen(false);
                    }}
                  >
                    Edit
                  </button>
                )}
                <button
                  type="button"
                  className={styles.cardMenuDanger}
                  onClick={() => {
                    onDeleteItem(item.id);
                    setMenuOpen(false);
                  }}
                >
                  Delete
                </button>
              </div>
            )}
          </div>
        )
      )}
      <div className={styles.cardBody}>
        <div className={styles.cardMedia}>{renderMedia(item, media, onOpenPhoto)}</div>
        <div className={styles.cardContent}>
          <div className={styles.cardMeta}>
            <span className={`${styles.kindBadge} ${styles[`kind_${item.kind}`]}`}>
              <KindIcon kind={item.kind} />
              {kindLabel}
            </span>
            <time dateTime={item.captured_at} className={styles.cardTime}>
              {time}
            </time>
          </div>
          {renderText(item, media)}
          {tags.length > 0 && (
            <div className={styles.tagRow}>
              {tags.map((tag) =>
                onToggleTag ? (
                  <button
                    key={tag.id}
                    type="button"
                    className={`${styles.tag} ${tagFilter?.has(tag.id) ? styles.tagActive : ""}`}
                    aria-pressed={tagFilter?.has(tag.id)}
                    onClick={() => onToggleTag(tag.id)}
                  >
                    {tag.name}
                  </button>
                ) : (
                  <span key={tag.id} className={styles.tag}>
                    {tag.name}
                  </span>
                ),
              )}
            </div>
          )}
        </div>
      </div>
    </article>
  );
}

function renderMedia(item: Item, media: MediaFile[], onOpenPhoto: (id: string, mediaId?: string) => void) {
  if (item.kind === "photo") {
    const { display } = getPhotoMedia(media);
    if (!display) {
      return <div className={`${styles.mediaIcon} ${styles.kind_photo}`}>🖼</div>;
    }
    return (
      <button
        type="button"
        className={styles.photoThumb}
        onClick={() => onOpenPhoto(item.id, display.id)}
        aria-label={`Photo, ${item.caption || "no caption"}`}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={itemThumbUrl(item.id, display, 192)} alt="" loading="lazy" />
      </button>
    );
  }

  if (item.kind === "voice") {
    return (
      <div className={`${styles.mediaIcon} ${styles.kind_voice}`} aria-hidden>
        <VoiceWaveIcon />
      </div>
    );
  }

  if (item.kind === "note") {
    return (
      <div className={`${styles.mediaIcon} ${styles.kind_note}`} aria-hidden>
        <NoteDocIcon />
      </div>
    );
  }

  const file = media.find((m) => m.role === "file") ?? media[0];
  const ext = file?.original_filename?.split(".").pop()?.toUpperCase() ?? "FILE";
  return (
    <div className={`${styles.mediaIcon} ${styles.kind_file}`} aria-hidden>
      {ext.slice(0, 3)}
    </div>
  );
}

function renderText(item: Item, media: MediaFile[]) {
  if (item.kind === "photo") {
    return item.caption ? <p className={styles.cardTitle}>{item.caption}</p> : null;
  }

  if (item.kind === "note") {
    return item.body ? <p className={styles.cardText}>{item.body}</p> : null;
  }

  if (item.kind === "voice") {
    const voice = media.find((m) => m.role === "voice_note") ?? media[0];
    const duration = voice?.duration_ms != null ? formatDuration(voice.duration_ms) : null;
    return (
      <>
        {voice && (
          <div className={styles.voicePlayer}>
            <audio controls preload="none" className={styles.audio} src={`/api/media/${voice.id}/download?inline=1`}>
              <track kind="captions" />
            </audio>
            {duration && <span className={styles.voiceDuration}>{duration}</span>}
          </div>
        )}
        {item.caption && <p className={styles.cardText}>{item.caption}</p>}
      </>
    );
  }

  const file = media.find((m) => m.role === "file") ?? media[0];
  if (!file) return <p className={styles.cardPending}>File pending upload…</p>;

  const label = file.original_filename || "Download file";
  const mime = file.mime_type?.split("/").pop()?.toUpperCase() ?? "FILE";
  const size = formatFileSize(file.size_bytes);

  return (
    <div className={styles.fileBlock}>
      <p className={styles.cardTitle}>{label}</p>
      <p className={styles.fileMeta}>
        {mime} · {size}
      </p>
      <a className={styles.fileDownload} href={`/api/media/${file.id}/download`} aria-label={`Download ${label}`}>
        ↓
      </a>
    </div>
  );
}

function KindIcon({ kind }: { kind: Item["kind"] }) {
  if (kind === "photo") return <PhotoKindIcon />;
  if (kind === "voice") return <VoiceKindIcon />;
  if (kind === "note") return <NoteKindIcon />;
  return <FileKindIcon />;
}

function PhotoKindIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <path d="M21 15l-5-5L5 21" />
    </svg>
  );
}

function VoiceKindIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
    </svg>
  );
}

function NoteKindIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}

function FileKindIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}

function TagIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
      <circle cx="7" cy="7" r="1.5" fill="currentColor" stroke="none" />
    </svg>
  );
}

function VoiceWaveIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
      <path d="M19 11v1a7 7 0 0 1-14 0v-1" />
    </svg>
  );
}

function NoteDocIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M8 13h8M8 17h5" />
    </svg>
  );
}
