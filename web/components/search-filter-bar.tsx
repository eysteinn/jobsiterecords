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
  mobile?: boolean;
  onOpenFilterSheet?: () => void;
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
  mobile = false,
  onOpenFilterSheet,
}: Props) {
  const labelId = useId();
  const internalRef = useRef<HTMLInputElement>(null);
  const resolvedRef = inputRef ?? internalRef;
  useSearchShortcut(resolvedRef, { enabled: !mobile });

  const hasFilters =
    query.trim().length > 0 || (activeChipIds != null && activeChipIds.size > 0);
  const showCount =
    hasFilters && shownCount != null && totalCount != null && shownCount !== totalCount;

  function handleMoreFilters() {
    if (mobile && onOpenFilterSheet) {
      onOpenFilterSheet();
    } else {
      onDetailedChange(!detailed);
    }
  }

  return (
    <div className={`${styles.bar} ${mobile ? styles.barMobile : ""}`} role="search" aria-labelledby={labelId}>
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
            className={`${styles.modeBtn} ${detailed || (mobile && hasFilters && activeChipIds && activeChipIds.size > 0) ? styles.modeBtnActive : ""}`}
            onClick={handleMoreFilters}
            aria-expanded={detailed}
            aria-controls={mobile ? undefined : `${labelId}-filters`}
            aria-label="More filters"
          >
            {mobile ? "Filters" : detailed ? "Simple" : "More filters"}
          </button>
        )}
      </div>
      {!mobile && detailed && chips && chips.length > 0 && (
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
        {!mobile && <span className={styles.hint}>/ to focus search</span>}
      </div>
    </div>
  );
}
