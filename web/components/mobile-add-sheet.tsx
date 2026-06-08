"use client";

import { useEffect } from "react";
import styles from "./mobile-add-sheet.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  jobName: string;
  onAddNote: () => void;
  readOnly?: boolean;
};

export function MobileAddSheet({ open, onClose, jobName, onAddNote, readOnly = false }: Props) {
  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open || readOnly) return null;

  return (
    <div className={styles.overlay} role="presentation" onClick={onClose}>
      <div
        className={styles.sheet}
        role="dialog"
        aria-modal="true"
        aria-label={`Add to ${jobName}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={styles.handle} aria-hidden />
        <h2 className={styles.title}>Add to {jobName}</h2>
        <p className={styles.subtitle}>Capture and store records</p>

        <button type="button" className={styles.option} disabled aria-disabled="true">
          <span className={styles.optionIcon} aria-hidden>📷</span>
          <span className={styles.optionBody}>
            <strong>Photo</strong>
            <span>Upload or take a photo — use the mobile app</span>
          </span>
        </button>

        <button type="button" className={styles.option} onClick={() => { onAddNote(); onClose(); }}>
          <span className={styles.optionIcon} aria-hidden>📝</span>
          <span className={styles.optionBody}>
            <strong>Text note</strong>
            <span>Write a quick note</span>
          </span>
        </button>

        <button type="button" className={styles.option} disabled aria-disabled="true">
          <span className={styles.optionIcon} aria-hidden>📄</span>
          <span className={styles.optionBody}>
            <strong>File / PDF</strong>
            <span>Upload a file — coming soon on web</span>
          </span>
        </button>

        <button type="button" className={styles.option} disabled aria-disabled="true">
          <span className={styles.optionIcon} aria-hidden>🎙</span>
          <span className={styles.optionBody}>
            <strong>Voice note</strong>
            <span>Upload or record — use the mobile app</span>
          </span>
        </button>

        <button type="button" className={styles.cancelBtn} onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  );
}
