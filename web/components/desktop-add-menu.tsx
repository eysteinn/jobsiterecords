"use client";

import { useEffect, useRef } from "react";
import styles from "./desktop-add-menu.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  onAddNote: () => void;
  onAddPhoto?: () => void;
  onAddVoice?: () => void;
  onAddFile?: () => void;
};

export function DesktopAddMenu({
  open,
  onClose,
  onAddNote,
  onAddPhoto,
  onAddVoice,
  onAddFile,
}: Props) {
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    function onPointerDown(e: PointerEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onClose();
      }
    }
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointerDown);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onPointerDown);
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className={styles.menu} ref={menuRef} role="menu" aria-label="Add to job">
      <p className={styles.menuTitle}>Add to job</p>
      <button
        type="button"
        className={styles.menuItem}
        role="menuitem"
        disabled
        aria-disabled="true"
        onClick={onAddPhoto}
      >
        <PhotoOptionIcon />
        Photo
      </button>
      <button
        type="button"
        className={styles.menuItem}
        role="menuitem"
        disabled
        aria-disabled="true"
        onClick={onAddVoice}
      >
        <VoiceOptionIcon />
        Voice note
      </button>
      <button
        type="button"
        className={styles.menuItem}
        role="menuitem"
        onClick={() => {
          onAddNote();
          onClose();
        }}
      >
        <NoteOptionIcon />
        Text note
      </button>
      <button
        type="button"
        className={styles.menuItem}
        role="menuitem"
        disabled
        aria-disabled="true"
        onClick={onAddFile}
      >
        <FileOptionIcon />
        File / PDF
      </button>
    </div>
  );
}

function PhotoOptionIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <path d="M21 15l-5-5L5 21" />
    </svg>
  );
}

function VoiceOptionIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
      <path d="M19 11v1a7 7 0 0 1-14 0v-1" />
    </svg>
  );
}

function NoteOptionIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M8 13h8M8 17h5" />
    </svg>
  );
}

function FileOptionIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}
