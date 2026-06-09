"use client";

import { useEffect, useMemo, useState } from "react";
import type { Tag } from "@/lib/api-jobs";
import { kindLabel, type ItemKind } from "@/lib/search";
import styles from "./mobile-timeline-filter-sheet.module.css";

export type TimelineSortOrder = "newest" | "oldest";

type Props = {
  open: boolean;
  onClose: () => void;
  kindFilter: ReadonlySet<ItemKind>;
  onToggleKind: (kind: ItemKind) => void;
  onClearKinds: () => void;
  allTags: Tag[];
  tagsInJob: ReadonlySet<string>;
  tagFilter: ReadonlySet<string>;
  onToggleTag: (tagId: string) => void;
  onClearTags: () => void;
  dateFrom: string;
  dateTo: string;
  onDateFromChange: (value: string) => void;
  onDateToChange: (value: string) => void;
  sortOrder: TimelineSortOrder;
  onSortOrderChange: (order: TimelineSortOrder) => void;
  onClearAll: () => void;
  hasActiveFilters: boolean;
};

const KIND_OPTIONS: ItemKind[] = ["photo", "voice", "note", "file"];

export function MobileTimelineFilterSheet({
  open,
  onClose,
  kindFilter,
  onToggleKind,
  onClearKinds,
  allTags,
  tagsInJob,
  tagFilter,
  onToggleTag,
  onClearTags,
  dateFrom,
  dateTo,
  onDateFromChange,
  onDateToChange,
  sortOrder,
  onSortOrderChange,
  onClearAll,
  hasActiveFilters,
}: Props) {
  const [tagSearch, setTagSearch] = useState("");

  useEffect(() => {
    if (!open) return;
    setTagSearch("");
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  const filteredTags = useMemo(() => {
    const needle = tagSearch.trim().toLowerCase();
    const tags = allTags.filter((tag) => tagsInJob.has(tag.id) || tagFilter.has(tag.id));
    if (!needle) return tags;
    return tags.filter((tag) => tag.name.toLowerCase().includes(needle));
  }, [allTags, tagsInJob, tagFilter, tagSearch]);

  if (!open) return null;

  return (
    <div className={styles.overlay} role="presentation" onClick={onClose}>
      <div
        className={styles.sheet}
        role="dialog"
        aria-modal="true"
        aria-label="Timeline filters"
        onClick={(e) => e.stopPropagation()}
      >
        <div className={styles.handle} aria-hidden />
        <div className={styles.header}>
          <h2>Filters</h2>
          <button type="button" className={styles.closeBtn} onClick={onClose} aria-label="Close filters">
            ×
          </button>
        </div>

        <section className={styles.section}>
          <h3 className={styles.sectionTitle}>Type</h3>
          <div className={styles.chips}>
            {KIND_OPTIONS.map((kind) => {
              const active = kindFilter.has(kind);
              return (
                <button
                  key={kind}
                  type="button"
                  className={active ? styles.chipActive : styles.chip}
                  aria-pressed={active}
                  onClick={() => onToggleKind(kind)}
                >
                  {kindLabel(kind)}
                </button>
              );
            })}
          </div>
          {kindFilter.size > 0 && (
            <button type="button" className={styles.sectionClear} onClick={onClearKinds}>
              Clear type
            </button>
          )}
        </section>

        <section className={styles.section}>
          <h3 className={styles.sectionTitle}>Tags</h3>
          {allTags.length > 6 && (
            <input
              type="search"
              className={styles.tagSearch}
              placeholder="Search tags"
              value={tagSearch}
              onChange={(e) => setTagSearch(e.target.value)}
              aria-label="Search tags"
            />
          )}
          {filteredTags.length > 0 ? (
            <div className={styles.chips}>
              {filteredTags.map((tag) => {
                const active = tagFilter.has(tag.id);
                return (
                  <button
                    key={tag.id}
                    type="button"
                    className={active ? styles.chipActive : styles.chip}
                    aria-pressed={active}
                    onClick={() => onToggleTag(tag.id)}
                  >
                    {tag.name}
                  </button>
                );
              })}
            </div>
          ) : (
            <p className={styles.emptyHint}>No tags in this job yet.</p>
          )}
          {tagFilter.size > 0 && (
            <button type="button" className={styles.sectionClear} onClick={onClearTags}>
              Clear tags
            </button>
          )}
        </section>

        <section className={styles.section}>
          <h3 className={styles.sectionTitle}>Date range</h3>
          <div className={styles.dateRow}>
            <label className={styles.dateField}>
              <span>From</span>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => onDateFromChange(e.target.value)}
              />
            </label>
            <label className={styles.dateField}>
              <span>To</span>
              <input
                type="date"
                value={dateTo}
                onChange={(e) => onDateToChange(e.target.value)}
              />
            </label>
          </div>
        </section>

        <section className={styles.section}>
          <h3 className={styles.sectionTitle}>Sort order</h3>
          <div className={styles.sortRow}>
            <button
              type="button"
              className={sortOrder === "newest" ? styles.sortActive : styles.sortBtn}
              aria-pressed={sortOrder === "newest"}
              onClick={() => onSortOrderChange("newest")}
            >
              Newest first
            </button>
            <button
              type="button"
              className={sortOrder === "oldest" ? styles.sortActive : styles.sortBtn}
              aria-pressed={sortOrder === "oldest"}
              onClick={() => onSortOrderChange("oldest")}
            >
              Oldest first
            </button>
          </div>
        </section>

        {hasActiveFilters && (
          <button type="button" className={styles.clearAllBtn} onClick={onClearAll}>
            Clear all filters
          </button>
        )}

        <button type="button" className={styles.doneBtn} onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}
