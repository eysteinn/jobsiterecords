"use client";

import { type RefObject, useId, useRef } from "react";
import { useSearchShortcut } from "@/hooks/use-search-shortcut";
import styles from "./search-filter-bar.module.css";

type Chip = {
  id: string;
  label: string;
};

type Props = {
  query: string;
  onQueryChange: (value: string) => void;
  placeholder?: string;
  detailed: boolean;
  onDetailedChange: (detailed: boolean) => void;
  chips?: Chip[];
  activeChipIds?: ReadonlySet<string>;
  onToggleChip?: (id: string) => void;
  shownCount?: number;
  totalCount?: number;
  inputRef?: RefObject<HTMLInputElement | null>;
};

export function SearchFilterBar({
  query,
  onQueryChange,
  placeholder = "Search…",
  detailed,
  onDetailedChange,
  chips,
  activeChipIds,
  onToggleChip,
  shownCount,
  totalCount,
  inputRef,
}: Props) {
  const labelId = useId();
  const internalRef = useRef<HTMLInputElement>(null);
  const resolvedRef = inputRef ?? internalRef;
  useSearchShortcut(resolvedRef);

  const hasFilters =
    query.trim().length > 0 || (activeChipIds != null && activeChipIds.size > 0);
  const showCount =
    hasFilters && shownCount != null && totalCount != null && shownCount !== totalCount;

  return (
    <div className={styles.bar} role="search" aria-labelledby={labelId}>
      <span id={labelId} className="sr-only">
        Search and filter
      </span>
      <div className={styles.row}>
        <div className={styles.searchWrap}>
          <input
            ref={resolvedRef}
            type="search"
            className={styles.searchInput}
            placeholder={placeholder}
            value={query}
            onChange={(e) => onQueryChange(e.target.value)}
            aria-label={placeholder}
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
        {chips && chips.length > 0 && (
          <button
            type="button"
            className={`${styles.modeBtn} ${detailed ? styles.modeBtnActive : ""}`}
            onClick={() => onDetailedChange(!detailed)}
            aria-expanded={detailed}
            aria-controls={`${labelId}-filters`}
          >
            {detailed ? "Simple" : "More filters"}
          </button>
        )}
      </div>
      {detailed && chips && chips.length > 0 && (
        <div id={`${labelId}-filters`} className={styles.filters}>
          {chips.map((chip) => {
            const active = activeChipIds?.has(chip.id) ?? false;
            return (
              <button
                key={chip.id}
                type="button"
                className={`${styles.chip} ${active ? styles.chipActive : ""}`}
                aria-pressed={active}
                onClick={() => onToggleChip?.(chip.id)}
              >
                {chip.label}
              </button>
            );
          })}
        </div>
      )}
      <div className={styles.row}>
        {showCount && (
          <p className={styles.meta}>
            {shownCount} of {totalCount}
          </p>
        )}
        <span className={styles.hint}>/ to focus search</span>
      </div>
    </div>
  );
}
