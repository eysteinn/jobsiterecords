"use client";

import { useEffect, useRef, useState, type ReactElement } from "react";
import type { Item, MediaFile, Tag } from "@/lib/api-jobs";
import { formatDayHeading, formatDuration, formatFileSize, formatTime } from "@/lib/format";
import { getPhotoMedia, itemThumbUrl } from "@/lib/photo-media";
import { kindLabel, type ItemKind } from "@/lib/search";
import styles from "./mobile-timeline.module.css";

type KindCounts = Record<ItemKind, number>;

type SummaryChipsProps = {
  totalCount: number;
  counts: KindCounts;
  kindFilter: ReadonlySet<ItemKind>;
  onSelectAll: () => void;
  onSelectKind: (kind: ItemKind) => void;
};

const KIND_META: { kind: ItemKind; label: string; Icon: () => ReactElement }[] = [
  { kind: "photo", label: "Photos", Icon: PhotoChipIcon },
  { kind: "note", label: "Notes", Icon: NoteChipIcon },
  { kind: "voice", label: "Voice", Icon: VoiceChipIcon },
  { kind: "file", label: "Files", Icon: FileChipIcon },
];

export function MobileSummaryChips({
  totalCount,
  counts,
  kindFilter,
  onSelectAll,
  onSelectKind,
}: SummaryChipsProps) {
  const allActive = kindFilter.size === 0;

  return (
    <div className={styles.summaryRow} role="group" aria-label="Filter by item type">
      <button
        type="button"
        className={allActive ? styles.summaryChipActive : styles.summaryChip}
        aria-pressed={allActive}
        onClick={onSelectAll}
      >
        <AllChipIcon />
        All {totalCount}
      </button>
      {KIND_META.map(({ kind, label, Icon }) => {
        const count = counts[kind];
        if (count === 0) return null;
        const active = kindFilter.size === 1 && kindFilter.has(kind);
        return (
          <button
            key={kind}
            type="button"
            className={active ? styles.summaryChipActive : styles.summaryChip}
            aria-pressed={active}
            onClick={() => onSelectKind(kind)}
          >
            <Icon />
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
  hasFilters: boolean;
  inputRef?: React.RefObject<HTMLInputElement | null>;
};

export function MobileTimelineToolbar({
  query,
  onQueryChange,
  onOpenFilters,
  hasFilters,
  inputRef,
}: ToolbarProps) {
  return (
    <div className={styles.toolbar}>
      <div className={styles.searchWrap}>
        <span className={styles.searchIcon} aria-hidden>
          <SearchIcon />
        </span>
        <input
          ref={inputRef}
          type="search"
          className={styles.searchInput}
          placeholder="Search timeline"
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
        className={`${styles.filterBtn} ${hasFilters ? styles.filterBtnActive : ""}`}
        onClick={onOpenFilters}
        aria-label="Open filters"
      >
        <FilterIcon />
        {hasFilters && <span className={styles.filterDot} aria-hidden />}
      </button>
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
  onViewItem?: (itemId: string) => void;
  onShareItem?: (itemId: string) => void;
  onAnnotateItem?: (itemId: string) => void;
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
  onViewItem,
  onShareItem,
  onAnnotateItem,
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
              onViewItem={onViewItem}
              onShareItem={onShareItem}
              onAnnotateItem={onAnnotateItem}
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
  onViewItem?: (itemId: string) => void;
  onShareItem?: (itemId: string) => void;
  onAnnotateItem?: (itemId: string) => void;
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
  onViewItem,
  onShareItem,
  onAnnotateItem,
  readOnly = false,
}: CardProps) {
  const time = formatTime(item.captured_at);
  const kindShortLabel =
    item.kind === "voice" ? "Voice" : item.kind.charAt(0).toUpperCase() + item.kind.slice(1);
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

  function handleCardClick() {
    if (selecting) {
      onToggleSelect?.(item.id);
      return;
    }
    if (item.kind === "photo") {
      const { display } = getPhotoMedia(media);
      onOpenPhoto(item.id, display?.id);
    }
  }

  return (
    <article
      className={`${styles.card} ${selecting ? styles.cardSelecting : ""} ${isSelected ? styles.cardSelected : ""}`}
      onPointerDown={handlePointerDown}
      onPointerUp={clearLongPress}
      onPointerLeave={clearLongPress}
      onPointerCancel={clearLongPress}
      onClick={selecting ? () => onToggleSelect?.(item.id) : undefined}
    >
      {selecting && (
        <input
          type="checkbox"
          className={styles.cardCheckbox}
          checked={isSelected}
          onChange={() => onToggleSelect?.(item.id)}
          aria-label={`Select ${kindShortLabel}`}
        />
      )}
      <div className={styles.cardBody}>
        <div className={styles.cardMedia}>{renderMedia(item, media, onOpenPhoto, selecting)}</div>
        <div className={styles.cardContent}>
          <div className={styles.cardHeaderRow}>
            <span className={`${styles.kindPill} ${styles[`kind_${item.kind}`]}`}>
              {kindShortLabel}
            </span>
            <time dateTime={item.captured_at} className={styles.cardTime}>
              {time}
            </time>
            {!selecting && !readOnly && onDeleteItem && (
              <div className={styles.cardMenuWrap} ref={menuRef}>
                <button
                  type="button"
                  className={styles.cardMenu}
                  aria-label="More options"
                  aria-expanded={menuOpen}
                  onClick={(e) => {
                    e.stopPropagation();
                    setMenuOpen((open) => !open);
                  }}
                >
                  ⋮
                </button>
                {menuOpen && (
                  <div className={styles.cardMenuDropdown}>
                    {onViewItem && (
                      <button
                        type="button"
                        onClick={() => {
                          onViewItem(item.id);
                          setMenuOpen(false);
                        }}
                      >
                        View
                      </button>
                    )}
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
                    {item.kind === "photo" && onAnnotateItem && (
                      <button
                        type="button"
                        onClick={() => {
                          onAnnotateItem(item.id);
                          setMenuOpen(false);
                        }}
                      >
                        Annotate
                      </button>
                    )}
                    {onShareItem && (
                      <button
                        type="button"
                        onClick={() => {
                          onShareItem(item.id);
                          setMenuOpen(false);
                        }}
                      >
                        Share
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
            )}
          </div>
          <div
            className={styles.cardTextArea}
            onClick={!selecting && item.kind === "photo" ? handleCardClick : undefined}
            onKeyDown={undefined}
            role={!selecting && item.kind === "photo" ? "button" : undefined}
            tabIndex={!selecting && item.kind === "photo" ? 0 : undefined}
          >
            {renderText(item, media)}
          </div>
          {tags.length > 0 && (
            <div className={styles.tagRow}>
              {tags.map((tag) =>
                onToggleTag ? (
                  <button
                    key={tag.id}
                    type="button"
                    className={`${styles.tag} ${tagFilter?.has(tag.id) ? styles.tagActive : ""}`}
                    aria-pressed={tagFilter?.has(tag.id)}
                    onClick={(e) => {
                      e.stopPropagation();
                      onToggleTag(tag.id);
                    }}
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

function renderMedia(
  item: Item,
  media: MediaFile[],
  onOpenPhoto: (id: string, mediaId?: string) => void,
  selecting: boolean,
) {
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
        disabled={selecting}
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

function SearchIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <circle cx="11" cy="11" r="8" />
      <path d="M21 21l-4.35-4.35" />
    </svg>
  );
}

function FilterIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M4 6h16M7 12h10M10 18h4" />
    </svg>
  );
}

function AllChipIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  );
}

function PhotoChipIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <path d="M21 15l-5-5L5 21" />
    </svg>
  );
}

function NoteChipIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6M8 13h8M8 17h5" />
    </svg>
  );
}

function VoiceChipIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
    </svg>
  );
}

function FileChipIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
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
