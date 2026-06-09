"use client";

import { type RefObject } from "react";
import { useSearchShortcut } from "@/hooks/use-search-shortcut";
import styles from "./desktop-timeline-toolbar.module.css";

type Props = {
  query: string;
  onQueryChange: (value: string) => void;
  onOpenFilters: () => void;
  hasFilters: boolean;
  selecting?: boolean;
  onSelectToggle?: () => void;
  readOnly?: boolean;
  inputRef?: RefObject<HTMLInputElement | null>;
};

export function DesktopTimelineToolbar({
  query,
  onQueryChange,
  onOpenFilters,
  hasFilters,
  selecting = false,
  onSelectToggle,
  readOnly = false,
  inputRef,
}: Props) {
  useSearchShortcut(inputRef ?? { current: null });

  return (
    <div className={styles.row}>
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
        Filter
        {hasFilters && <span className={styles.filterDot} aria-hidden />}
      </button>
      {!readOnly && onSelectToggle && (
        <button
          type="button"
          className={`${styles.selectBtn} ${selecting ? styles.selectBtnActive : ""}`}
          onClick={onSelectToggle}
          aria-pressed={selecting}
        >
          <CheckboxIcon />
          {selecting ? "Cancel" : "Select items"}
        </button>
      )}
    </div>
  );
}

function SearchIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <circle cx="11" cy="11" r="8" />
      <path d="M21 21l-4.35-4.35" />
    </svg>
  );
}

function FilterIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M22 3H2l8 9.46V19l4 2v-8.54L22 3z" />
    </svg>
  );
}

function CheckboxIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="2" />
    </svg>
  );
}
