"use client";

import { type ReactNode, useEffect } from "react";
import styles from "./mobile-filter-sheet.module.css";

type Chip = {
  id: string;
  label: string;
};

type Props = {
  open: boolean;
  onClose: () => void;
  title?: string;
  chips: Chip[];
  activeChipIds: ReadonlySet<string>;
  onToggleChip: (id: string) => void;
  onClear: () => void;
  extraAction?: ReactNode;
};

export function MobileFilterSheet({
  open,
  onClose,
  title = "Filters",
  chips,
  activeChipIds,
  onToggleChip,
  onClear,
  extraAction,
}: Props) {
  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className={styles.overlay} role="presentation" onClick={onClose}>
      <div
        className={styles.sheet}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={styles.handle} aria-hidden />
        <div className={styles.header}>
          <h2>{title}</h2>
          <button type="button" className={styles.closeBtn} onClick={onClose} aria-label="Close filters">
            ×
          </button>
        </div>
        {extraAction}
        <div className={styles.chips}>
          {chips.map((chip) => {
            const active = activeChipIds.has(chip.id);
            return (
              <button
                key={chip.id}
                type="button"
                className={active ? styles.chipActive : styles.chip}
                aria-pressed={active}
                onClick={() => onToggleChip(chip.id)}
              >
                {chip.label}
              </button>
            );
          })}
        </div>
        {activeChipIds.size > 0 && (
          <button type="button" className={styles.clearBtn} onClick={onClear}>
            Clear filters
          </button>
        )}
        <button type="button" className={styles.doneBtn} onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}
