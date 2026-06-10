"use client";

import type { Tag } from "@/lib/api-jobs";
import styles from "./tag-chips.module.css";

type Props = {
  allTags: Tag[];
  selectedIds: ReadonlySet<string>;
  partialIds?: ReadonlySet<string>;
  onToggle: (tagId: string) => void;
  onAddTag?: () => void;
  disabled?: boolean;
  label?: string;
};

export function TagChips({
  allTags,
  selectedIds,
  partialIds,
  onToggle,
  onAddTag,
  disabled = false,
  label,
}: Props) {
  return (
    <div>
      {label && <span className={styles.label}>{label}</span>}
      <div className={styles.wrap} role="group" aria-label={label ?? "Tags"}>
        {allTags.map((tag) => {
          const selected = selectedIds.has(tag.id);
          const partial = !selected && (partialIds?.has(tag.id) ?? false);
          const className = selected
            ? `${styles.chip} ${styles.chipSelected}`
            : partial
              ? `${styles.chip} ${styles.chipPartial}`
              : styles.chip;
          return (
            <button
              key={tag.id}
              type="button"
              className={className}
              aria-pressed={selected}
              disabled={disabled}
              onClick={() => onToggle(tag.id)}
            >
              {partial && <span className={styles.partialMark} aria-hidden>−</span>}
              {tag.name}
            </button>
          );
        })}
        {onAddTag && (
          <button type="button" className={styles.addChip} disabled={disabled} onClick={onAddTag}>
            + Add tag
          </button>
        )}
      </div>
    </div>
  );
}
