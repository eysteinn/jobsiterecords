"use client";

import { useEffect, useMemo, useState } from "react";
import type { ItemTag, Tag } from "@/lib/api-jobs";
import { buildItemTagsMap, tagCoverageForItemTags } from "@/lib/tags";
import { AddTagDialog } from "@/components/add-tag-dialog";
import { TagChips } from "@/components/tag-chips";
import styles from "./bulk-tag-sheet.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  selectedItemIds: ReadonlySet<string>;
  allTags: Tag[];
  itemTags: ItemTag[];
  onApply: (pending: Map<string, Set<string>>) => Promise<void>;
  onCreateTag: (name: string) => Promise<Tag>;
};

export function BulkTagSheet({
  open,
  onClose,
  selectedItemIds,
  allTags,
  itemTags,
  onApply,
  onCreateTag,
}: Props) {
  const [pending, setPending] = useState<Map<string, Set<string>> | null>(null);
  const [busy, setBusy] = useState(false);
  const [addTagOpen, setAddTagOpen] = useState(false);

  useEffect(() => {
    if (!open) {
      setPending(null);
      setBusy(false);
      setAddTagOpen(false);
      return;
    }
    setPending(buildItemTagsMap(itemTags, selectedItemIds));
  }, [open, itemTags, selectedItemIds]);

  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape" && !busy) onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose, busy]);

  const coverage = useMemo(() => {
    if (!pending) return { all: new Set<string>(), partial: new Set<string>() };
    return tagCoverageForItemTags(pending, selectedItemIds);
  }, [pending, selectedItemIds]);

  if (!open || !pending) return null;

  const count = selectedItemIds.size;

  function toggleTag(tagId: string) {
    setPending((prev) => {
      if (!prev) return prev;
      const allHaveTag = [...selectedItemIds].every((itemId) => prev.get(itemId)?.has(tagId));
      const next = new Map(prev);
      for (const itemId of selectedItemIds) {
        const tags = new Set(next.get(itemId) ?? []);
        if (allHaveTag) tags.delete(tagId);
        else tags.add(tagId);
        next.set(itemId, tags);
      }
      return next;
    });
  }

  async function handleDone() {
    if (!pending) return;
    setBusy(true);
    try {
      await onApply(pending);
      onClose();
    } finally {
      setBusy(false);
    }
  }

  async function handleCreateTag(name: string) {
    const tag = await onCreateTag(name);
    setPending((prev) => {
      if (!prev) return prev;
      const next = new Map(prev);
      for (const itemId of selectedItemIds) {
        const tags = new Set(next.get(itemId) ?? []);
        tags.add(tag.id);
        next.set(itemId, tags);
      }
      return next;
    });
  }

  return (
    <>
      <div className={styles.overlay} role="presentation" onClick={busy ? undefined : onClose}>
        <div
          className={styles.sheet}
          role="dialog"
          aria-modal="true"
          aria-label="Bulk tag assignment"
          onClick={(e) => e.stopPropagation()}
        >
          <div>
            <div className={styles.handle} aria-hidden />
            <h2 className={styles.title}>
              Tags for {count} item{count === 1 ? "" : "s"}
            </h2>
            <p className={styles.subtitle}>Tap tags to choose changes. Press Done to apply.</p>
          </div>
          <div className={styles.body}>
            <TagChips
              allTags={allTags}
              selectedIds={coverage.all}
              partialIds={coverage.partial}
              onToggle={toggleTag}
              onAddTag={() => setAddTagOpen(true)}
              disabled={busy}
            />
          </div>
          <div className={styles.footer}>
            <button type="button" className={styles.textBtn} disabled={busy} onClick={onClose}>
              Cancel
            </button>
            <button type="button" className={styles.primaryBtn} disabled={busy} onClick={() => void handleDone()}>
              {busy ? "Saving…" : "Done"}
            </button>
          </div>
        </div>
      </div>
      <AddTagDialog open={addTagOpen} onClose={() => setAddTagOpen(false)} onSave={handleCreateTag} />
    </>
  );
}
