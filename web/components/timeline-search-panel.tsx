"use client";

import { type RefObject, useEffect, useId, useMemo, useRef, useState } from "react";
import type { Tag } from "@/lib/api-jobs";
import { useSearchShortcut } from "@/hooks/use-search-shortcut";
import { buildActiveFilterLabels, kindLabel, type ItemKind } from "@/lib/search";
import styles from "./timeline-search-panel.module.css";

const KINDS: ItemKind[] = ["photo", "voice", "note", "file"];

type Props = {
  query: string;
  onQueryChange: (value: string) => void;
  kindFilter: ReadonlySet<ItemKind>;
  onToggleKind: (kind: ItemKind) => void;
  tagFilter: ReadonlySet<string>;
  onToggleTag: (tagId: string) => void;
  tags: Tag[];
  expanded: boolean;
  onExpandedChange: (expanded: boolean) => void;
  onClearFilters: () => void;
  shownCount: number;
  totalCount: number;
  inputRef?: RefObject<HTMLInputElement | null>;
};

export function TimelineSearchPanel({
  query,
  onQueryChange,
  kindFilter,
  onToggleKind,
  tagFilter,
  onToggleTag,
  tags,
  expanded,
  onExpandedChange,
  onClearFilters,
  shownCount,
  totalCount,
  inputRef,
}: Props) {
  const labelId = useId();
  const internalRef = useRef<HTMLInputElement>(null);
  const resolvedRef = inputRef ?? internalRef;
  const tagMenuRef = useRef<HTMLDivElement>(null);
  const [tagMenuOpen, setTagMenuOpen] = useState(false);
  const [tagMenuSearch, setTagMenuSearch] = useState("");
  useSearchShortcut(resolvedRef);

  const hasFilters =
    query.trim().length > 0 || kindFilter.size > 0 || tagFilter.size > 0;
  const summary = buildActiveFilterLabels(query, kindFilter, tagFilter, tags).join(" · ");
  const quickTags = tags.slice(0, 6);
  const moreTagCount = Math.max(0, tags.length - quickTags.length);

  const filteredTagMenu = useMemo(() => {
    const needle = tagMenuSearch.trim().toLowerCase();
    if (!needle) return tags;
    return tags.filter((tag) => tag.name.toLowerCase().includes(needle));
  }, [tagMenuSearch, tags]);

  useEffect(() => {
    if (!tagMenuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (tagMenuRef.current && !tagMenuRef.current.contains(event.target as Node)) {
        setTagMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [tagMenuOpen]);

  function toggleExpanded() {
    if (expanded) {
      onExpandedChange(false);
      return;
    }
    onExpandedChange(true);
    window.requestAnimationFrame(() => resolvedRef.current?.focus());
  }

  return (
    <div className={styles.wrap} role="search" aria-labelledby={labelId}>
      <span id={labelId} className="sr-only">
        Timeline search and filters
      </span>
      <div className={styles.toolbar}>
        <button
          type="button"
          className={`${styles.searchToggle} ${expanded ? styles.searchToggleActive : ""}`}
          onClick={toggleExpanded}
          aria-expanded={expanded}
        >
          {hasFilters && !expanded && <span className={styles.badge} aria-hidden />}
          {expanded ? "Close search" : "Search & filter"}
        </button>
        {hasFilters && (
          <span className={styles.timelineCount}>
            {shownCount} of {totalCount}
          </span>
        )}
      </div>

      {!expanded && hasFilters && (
        <div className={styles.summary} onClick={() => onExpandedChange(true)} role="button" tabIndex={0}>
          <span className={styles.summaryText}>{summary}</span>
          <button
            type="button"
            className={styles.summaryClear}
            aria-label="Clear filters"
            onClick={(e) => {
              e.stopPropagation();
              onClearFilters();
            }}
          >
            ×
          </button>
        </div>
      )}

      {expanded && (
        <div className={styles.panel}>
          <div className={styles.searchWrap}>
            <input
              ref={resolvedRef}
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

          <div className={styles.chipRow}>
            {KINDS.map((kind) => {
              const active = kindFilter.has(kind);
              return (
                <button
                  key={kind}
                  type="button"
                  className={`${styles.chip} ${active ? styles.chipActive : ""}`}
                  aria-pressed={active}
                  onClick={() => onToggleKind(kind)}
                >
                  {kindLabel(kind)}
                </button>
              );
            })}

            {tags.length > 0 && (
              <div className={styles.tagMenuWrap} ref={tagMenuRef}>
                <button
                  type="button"
                  className={`${styles.chip} ${tagFilter.size > 0 ? styles.tagChipActive : ""}`}
                  aria-expanded={tagMenuOpen}
                  onClick={() => setTagMenuOpen((open) => !open)}
                >
                  {tagFilter.size === 0 ? "Tags" : `Tags (${tagFilter.size})`}
                </button>
                {tagMenuOpen && (
                  <div className={styles.tagMenu} role="listbox" aria-label="Filter by tag">
                    <input
                      className={styles.tagMenuSearch}
                      placeholder="Search tags"
                      value={tagMenuSearch}
                      onChange={(e) => setTagMenuSearch(e.target.value)}
                    />
                    {filteredTagMenu.map((tag) => {
                      const active = tagFilter.has(tag.id);
                      return (
                        <button
                          key={tag.id}
                          type="button"
                          role="option"
                          aria-selected={active}
                          className={`${styles.tagMenuItem} ${active ? styles.tagMenuItemActive : ""}`}
                          onClick={() => onToggleTag(tag.id)}
                        >
                          {tag.name}
                        </button>
                      );
                    })}
                    {filteredTagMenu.length === 0 && (
                      <p className={styles.timelineCount}>No tags match your search.</p>
                    )}
                  </div>
                )}
              </div>
            )}

            {hasFilters && (
              <button type="button" className={`${styles.chip} ${styles.clearChip}`} onClick={onClearFilters}>
                Clear
              </button>
            )}
          </div>

          {quickTags.length > 0 && (
            <div className={styles.chipRow}>
              {quickTags.map((tag) => {
                const active = tagFilter.has(tag.id);
                return (
                  <button
                    key={tag.id}
                    type="button"
                    className={`${styles.chip} ${active ? styles.tagChipActive : ""}`}
                    aria-pressed={active}
                    onClick={() => onToggleTag(tag.id)}
                  >
                    {tag.name}
                  </button>
                );
              })}
              {moreTagCount > 0 && (
                <button type="button" className={`${styles.chip} ${styles.clearChip}`} onClick={() => setTagMenuOpen(true)}>
                  +{moreTagCount} more
                </button>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export function TimelineFilteredEmpty({ onClear }: { onClear: () => void }) {
  return (
    <div className={styles.filteredEmpty}>
      <h3>No items match your filters</h3>
      <p>Try a different search term or clear filters to see everything.</p>
      <button type="button" onClick={onClear}>
        Clear filters
      </button>
    </div>
  );
}

export function TimelineSectionHeader({
  shownCount,
  totalCount,
  hasFilters,
}: {
  shownCount: number;
  totalCount: number;
  hasFilters: boolean;
}) {
  return (
    <div className={styles.timelineHeader}>
      <h2>Timeline</h2>
      {hasFilters && (
        <span className={styles.timelineCount}>
          {shownCount} of {totalCount}
        </span>
      )}
    </div>
  );
}
