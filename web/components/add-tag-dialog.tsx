"use client";

import { useEffect, useRef, useState } from "react";
import styles from "./add-tag-dialog.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  onSave: (name: string) => Promise<void>;
};

export function AddTagDialog({ open, onClose, onSave }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [name, setName] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setName("");
    setError(null);
    setSaving(false);
    window.requestAnimationFrame(() => inputRef.current?.focus());
  }, [open]);

  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape" && !saving) onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose, saving]);

  if (!open) return null;

  async function handleSave() {
    const trimmed = name.trim();
    if (!trimmed) return;
    setSaving(true);
    setError(null);
    try {
      await onSave(trimmed);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create tag");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className={styles.overlay} role="presentation" onClick={saving ? undefined : onClose}>
      <div
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-label="New tag"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className={styles.title}>New tag</h2>
        <input
          ref={inputRef}
          type="text"
          className={styles.input}
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Plumbing"
          maxLength={40}
          onKeyDown={(e) => {
            if (e.key === "Enter") void handleSave();
          }}
        />
        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}
        <div className={styles.actions}>
          <button type="button" className={styles.cancelBtn} disabled={saving} onClick={onClose}>
            Cancel
          </button>
          <button
            type="button"
            className={styles.saveBtn}
            disabled={saving || !name.trim()}
            onClick={() => void handleSave()}
          >
            {saving ? "Adding…" : "Add"}
          </button>
        </div>
      </div>
    </div>
  );
}
