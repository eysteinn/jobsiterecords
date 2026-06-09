"use client";

import { useEffect, useMemo, useState } from "react";
import type { Item } from "@/lib/api-jobs";
import { formatDate, formatDayKey } from "@/lib/format";
import { kindLabel } from "@/lib/search";
import type { TimelineSortOrder } from "@/components/mobile-timeline-filter-sheet";
import styles from "./export-job-modal.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  jobName: string;
  items: Item[];
  initialSelectedIds?: Set<string>;
  onExport?: (options: ExportOptions) => void;
};

export type ExportOptions = {
  itemIds: string[];
  dateFrom: string;
  dateTo: string;
  sortOrder: TimelineSortOrder;
  includeCaptions: boolean;
  includeTags: boolean;
  includeTimestamps: boolean;
};

export function ExportJobModal({
  open,
  onClose,
  jobName,
  items,
  initialSelectedIds,
  onExport,
}: Props) {
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [sortOrder, setSortOrder] = useState<TimelineSortOrder>("newest");
  const [includeCaptions, setIncludeCaptions] = useState(true);
  const [includeTags, setIncludeTags] = useState(true);
  const [includeTimestamps, setIncludeTimestamps] = useState(true);

  const grouped = useMemo(() => {
    const map = new Map<string, Item[]>();
    for (const item of items) {
      const day = formatDayKey(item.captured_at);
      const list = map.get(day) ?? [];
      list.push(item);
      map.set(day, list);
    }
    return [...map.entries()].sort(([a], [b]) => b.localeCompare(a));
  }, [items]);

  useEffect(() => {
    if (!open) return;
    setSelected(initialSelectedIds ? new Set(initialSelectedIds) : new Set(items.map((i) => i.id)));
    setDateFrom("");
    setDateTo("");
    setSortOrder("newest");
    setIncludeCaptions(true);
    setIncludeTags(true);
    setIncludeTimestamps(true);
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, items, initialSelectedIds, onClose]);

  if (!open) return null;

  const allSelected = selected.size === items.length && items.length > 0;

  function toggleAll() {
    if (allSelected) {
      setSelected(new Set());
      return;
    }
    setSelected(new Set(items.map((i) => i.id)));
  }

  function toggleItem(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function handleExport() {
    onExport?.({
      itemIds: [...selected],
      dateFrom,
      dateTo,
      sortOrder,
      includeCaptions,
      includeTags,
      includeTimestamps,
    });
    onClose();
  }

  return (
    <div className={styles.overlay} role="presentation" onClick={onClose}>
      <div
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-label={`Export ${jobName}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={styles.header}>
          <h2 className={styles.title}>Export job</h2>
          <button type="button" className={styles.closeBtn} onClick={onClose} aria-label="Close">
            ×
          </button>
        </div>

        <label className={styles.selectAll}>
          <input type="checkbox" checked={allSelected} onChange={toggleAll} />
          Select all
        </label>

        <div className={styles.itemList}>
          {grouped.map(([dayKey, dayItems]) => (
            <div key={dayKey} className={styles.dayGroup}>
              <p className={styles.dayLabel}>{formatDate(`${dayKey}T12:00:00.000Z`)}</p>
              {dayItems.map((item) => (
                <label key={item.id} className={styles.itemRow}>
                  <input
                    type="checkbox"
                    checked={selected.has(item.id)}
                    onChange={() => toggleItem(item.id)}
                  />
                  <span className={styles.itemKind}>{kindLabel(item.kind)}</span>
                  <span className={styles.itemPreview}>
                    {item.caption || item.body || "Untitled"}
                  </span>
                </label>
              ))}
            </div>
          ))}
        </div>

        <div className={styles.optionsGrid}>
          <label className={styles.field}>
            <span>Date from</span>
            <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
          </label>
          <label className={styles.field}>
            <span>Date to</span>
            <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
          </label>
          <label className={styles.field}>
            <span>Sort order</span>
            <select
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value as TimelineSortOrder)}
            >
              <option value="newest">Newest first</option>
              <option value="oldest">Oldest first</option>
            </select>
          </label>
        </div>

        <div className={styles.checks}>
          <label>
            <input
              type="checkbox"
              checked={includeCaptions}
              onChange={(e) => setIncludeCaptions(e.target.checked)}
            />
            Include captions
          </label>
          <label>
            <input
              type="checkbox"
              checked={includeTags}
              onChange={(e) => setIncludeTags(e.target.checked)}
            />
            Include tags
          </label>
          <label>
            <input
              type="checkbox"
              checked={includeTimestamps}
              onChange={(e) => setIncludeTimestamps(e.target.checked)}
            />
            Include timestamps
          </label>
        </div>

        <div className={styles.actions}>
          <button type="button" className={styles.cancelBtn} onClick={onClose}>
            Cancel
          </button>
          <button
            type="button"
            className={styles.exportBtn}
            disabled={selected.size === 0}
            onClick={handleExport}
          >
            Export / Download
          </button>
        </div>
      </div>
    </div>
  );
}
