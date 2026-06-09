"use client";

import { useEffect, useRef } from "react";
import styles from "./add-note-modal.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  caption: string;
  body: string;
  onCaptionChange: (value: string) => void;
  onBodyChange: (value: string) => void;
  onSave: () => void;
  saving?: boolean;
  error?: string | null;
};

export function AddNoteModal({
  open,
  onClose,
  caption,
  body,
  onCaptionChange,
  onBodyChange,
  onSave,
  saving = false,
  error,
}: Props) {
  const bodyRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    window.requestAnimationFrame(() => bodyRef.current?.focus());
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className={styles.overlay} role="presentation" onClick={onClose}>
      <div
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-label="Add text note"
        onClick={(e) => e.stopPropagation()}
      >
        <div className={styles.header}>
          <h2 className={styles.title}>Text note</h2>
          <button type="button" className={styles.closeBtn} onClick={onClose} aria-label="Close">
            ×
          </button>
        </div>

        <label className={styles.field}>
          <span className={styles.label}>Caption (optional)</span>
          <input
            type="text"
            value={caption}
            onChange={(e) => onCaptionChange(e.target.value)}
            placeholder="Caption"
          />
        </label>

        <label className={styles.field}>
          <span className={styles.label}>Note body</span>
          <textarea
            ref={bodyRef}
            rows={5}
            value={body}
            onChange={(e) => onBodyChange(e.target.value)}
            placeholder="Write your note…"
          />
        </label>

        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}

        <div className={styles.actions}>
          <button type="button" className={styles.cancelBtn} onClick={onClose}>
            Cancel
          </button>
          <button
            type="button"
            className={styles.saveBtn}
            disabled={saving || !body.trim()}
            onClick={onSave}
          >
            {saving ? "Saving…" : "Save note"}
          </button>
        </div>
      </div>
    </div>
  );
}
