"use client";

import { useEffect } from "react";
import styles from "./undo-toast.module.css";

type Props = {
  message: string;
  undoLabel?: string;
  durationMs?: number;
  onUndo?: () => void;
  onDismiss: () => void;
};

export function UndoToast({
  message,
  undoLabel = "Undo",
  durationMs = 5000,
  onUndo,
  onDismiss,
}: Props) {
  useEffect(() => {
    const timer = window.setTimeout(onDismiss, durationMs);
    return () => window.clearTimeout(timer);
  }, [durationMs, onDismiss]);

  return (
    <div className={styles.toast} role="status" aria-live="polite">
      <span>{message}</span>
      {onUndo && (
        <button type="button" className={styles.undoBtn} onClick={onUndo}>
          {undoLabel}
        </button>
      )}
      <button type="button" className={styles.dismissBtn} onClick={onDismiss} aria-label="Dismiss">
        ×
      </button>
    </div>
  );
}
