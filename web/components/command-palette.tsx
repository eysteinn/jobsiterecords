"use client";

import { useEffect } from "react";
import styles from "./command-palette.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
};

const commands = [
  "Go to Jobs",
  "Go to Reports",
  "Go to Team",
  "Go to Settings",
  "Sign out",
];

export function CommandPalette({ open, onClose }: Props) {
  useEffect(() => {
    if (!open) return;
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className={styles.backdrop} onClick={onClose} role="presentation">
      <div
        className={styles.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-label="Command palette"
      >
        <input
          className={styles.input}
          placeholder="Type a command…"
          autoFocus
          readOnly
        />
        <ul className={styles.list}>
          {commands.map((cmd) => (
            <li key={cmd}>{cmd}</li>
          ))}
        </ul>
        <p className={styles.hint}>M1 placeholder — navigation wiring comes later.</p>
      </div>
    </div>
  );
}
