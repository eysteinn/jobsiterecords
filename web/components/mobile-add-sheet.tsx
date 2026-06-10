"use client";

import { useEffect } from "react";
import styles from "./mobile-add-sheet.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  jobName: string;
  onAddNote: () => void;
  onAddPhoto?: () => void;
  onAddVoice?: () => void;
  readOnly?: boolean;
};

export function MobileAddSheet({
  open,
  onClose,
  jobName,
  onAddNote,
  onAddPhoto,
  onAddVoice,
  readOnly = false,
}: Props) {
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

        <button
          type="button"
          className={styles.option}
          onClick={() => {
            onAddPhoto?.();
            onClose();
          }}
        >
          <span className={styles.optionIcon} aria-hidden>
            <PhotoOptionIcon />
          </span>
          <span className={styles.optionBody}>
            <strong>Photo</strong>
            <span>Take a photo or choose from library</span>
          </span>
        </button>

        <button
          type="button"
          className={styles.option}
          onClick={() => {
            onAddVoice?.();
            onClose();
          }}
        >
          <span className={styles.optionIcon} aria-hidden>
            <VoiceOptionIcon />
          </span>
          <span className={styles.optionBody}>
            <strong>Voice note</strong>
            <span>Record on site</span>
          </span>
        </button>

        <button type="button" className={styles.option} onClick={() => { onAddNote(); onClose(); }}>
          <span className={styles.optionIcon} aria-hidden>
            <NoteOptionIcon />
          </span>
          <span className={styles.optionBody}>
            <strong>Text note</strong>
            <span>Write a quick note</span>
          </span>
        </button>

        <button type="button" className={styles.option} disabled aria-disabled="true">
          <span className={styles.optionIcon} aria-hidden>
            <FileOptionIcon />
          </span>
          <span className={styles.optionBody}>
            <strong>File / PDF</strong>
            <span>Upload a file — coming soon on web</span>
          </span>
        </button>

        <button type="button" className={styles.cancelBtn} onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  );
}

function PhotoOptionIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <path d="M21 15l-5-5L5 21" />
    </svg>
  );
}

function VoiceOptionIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
      <path d="M19 11v1a7 7 0 0 1-14 0v-1" />
    </svg>
  );
}

function NoteOptionIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M8 13h8M8 17h5" />
    </svg>
  );
}

function FileOptionIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}
