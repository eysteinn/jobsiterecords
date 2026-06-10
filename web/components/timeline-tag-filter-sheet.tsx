"use client";

import { useEffect, useMemo, useState } from "react";
import type { Tag } from "@/lib/api-jobs";
import styles from "./timeline-tag-filter-sheet.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  allTags: Tag[];
  tagsInJob: ReadonlySet<string>;
  selectedTagIds: ReadonlySet<string>;
  onApply: (tagIds: Set<string>) => void;
};

export function TimelineTagFilterSheet({
  open,
  onClose,
  allTags,
  tagsInJob,
  selectedTagIds,
  onApply,
}: Props) {
  const [draft, setDraft] = useState<Set<string>>(new Set(selectedTagIds));
  const [search, setSearch] = useState("");

  useEffect(() => {
    if (!open) return;
    setDraft(new Set(selectedTagIds));
    setSearch("");
  }, [open, selectedTagIds]);

  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  const filtered = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return allTags;
    return allTags.filter((tag) => tag.name.toLowerCase().includes(needle));
  }, [allTags, search]);

  const inJob = useMemo(
    () => filtered.filter((tag) => tagsInJob.has(tag.id)),
    [filtered, tagsInJob],
  );
  const other = useMemo(
    () => filtered.filter((tag) => !tagsInJob.has(tag.id)),
    [filtered, tagsInJob],
  );

  if (!open) return null;

  function toggle(tagId: string) {
    setDraft((prev) => {
      const next = new Set(prev);
      if (!next.add(tagId)) next.delete(tagId);
      return next;
    });
  }

  function renderChips(tags: Tag[]) {
    return (
      <div className={styles.chips}>
        {tags.map((tag) => {
          const active = draft.has(tag.id);
          return (
            <button
              key={tag.id}
              type="button"
              className={active ? styles.chipActive : styles.chip}
              aria-pressed={active}
              onClick={() => toggle(tag.id)}
            >
              {tag.name}
            </button>
          );
        })}
      </div>
    );
  }

  return (
    <div className={styles.overlay} role="presentation" onClick={onClose}>
      <div
        className={styles.sheet}
        role="dialog"
        aria-modal="true"
        aria-label="Filter by tag"
        onClick={(event) => event.stopPropagation()}
      >
        <div className={styles.handle} aria-hidden />
        <div className={styles.header}>
          <h2>Filter by tag</h2>
          <p className={styles.subtitle}>Show items that have any of the selected tags.</p>
        </div>
        <input
          className={styles.searchInput}
          placeholder="Search tags"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          aria-label="Search tags"
        />
        <div className={styles.body}>
          {allTags.length === 0 ? (
            <p className={styles.empty}>
              No tags in this workspace yet. Add tags when editing items or capturing new ones.
            </p>
          ) : filtered.length === 0 ? (
            <p className={styles.empty}>No tags match your search.</p>
          ) : (
            <>
              {inJob.length > 0 && (
                <section className={styles.section}>
                  <p className={styles.sectionLabel}>In this job</p>
                  {renderChips(inJob)}
                </section>
              )}
              {other.length > 0 && (
                <section className={styles.section}>
                  {inJob.length > 0 && <p className={styles.sectionLabel}>All tags</p>}
                  {renderChips(other)}
                </section>
              )}
            </>
          )}
        </div>
        <div className={styles.footer}>
          {draft.size > 0 ? (
            <button type="button" className={styles.textBtn} onClick={() => setDraft(new Set())}>
              Clear
            </button>
          ) : (
            <span className={styles.footerSpacer} />
          )}
          <span className={styles.footerSpacer} />
          <button type="button" className={styles.textBtn} onClick={onClose}>
            Cancel
          </button>
          <button
            type="button"
            className={styles.primaryBtn}
            onClick={() => {
              onApply(draft);
              onClose();
            }}
          >
            {draft.size === 0 ? "Done" : `Done (${draft.size})`}
          </button>
        </div>
      </div>
    </div>
  );
}
