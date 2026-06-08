"use client";

import { useEffect, useRef, useState } from "react";
import styles from "./item-actions-menu.module.css";

type Props = {
  onEdit?: () => void;
  onDelete: () => void;
  align?: "left" | "right";
  className?: string;
  overlay?: boolean;
};

export function ItemActionsMenu({ onEdit, onDelete, align = "right", className, overlay = false }: Props) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onPointerDown(event: PointerEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [open]);

  return (
    <div className={`${styles.wrap} ${overlay ? styles.overlay : ""} ${className ?? ""}`} ref={ref}>
      <button
        type="button"
        className={styles.trigger}
        aria-label="Item options"
        aria-expanded={open}
        onClick={(e) => {
          e.stopPropagation();
          setOpen((value) => !value);
        }}
      >
        ⋮
      </button>
      {open && (
        <div className={align === "right" ? styles.menu : `${styles.menu} ${styles.menuLeft}`}>
          {onEdit && (
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                setOpen(false);
                onEdit();
              }}
            >
              Edit
            </button>
          )}
          <button
            type="button"
            className={styles.danger}
            onClick={(e) => {
              e.stopPropagation();
              setOpen(false);
              onDelete();
            }}
          >
            <TrashIcon />
            Delete
          </button>
        </div>
      )}
    </div>
  );
}

function TrashIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6" />
      <path d="M10 11v6M14 11v6" />
    </svg>
  );
}
