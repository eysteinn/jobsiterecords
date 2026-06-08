"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { Job } from "@/lib/api-jobs";
import { formatUpdatedLabel } from "@/lib/format";
import { itemThumbUrl } from "@/lib/photo-media";
import styles from "./mobile-job-card.module.css";

type Props = {
  job: Job;
  onDelete?: () => void;
};

function statusLabel(status: Job["status"]): string {
  return status.replace(/_/g, " ");
}

export function MobileJobCard({ job, onDelete }: Props) {
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const href = `/jobs/${job.id}`;

  useEffect(() => {
    if (!menuOpen) return;
    function onPointerDown(event: PointerEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [menuOpen]);
  const subtitle = job.address || job.client_name || null;
  const updated = formatUpdatedLabel(job.last_activity_at ?? job.updated_at);
  const thumbSrc = job.cover_item_id
    ? itemThumbUrl(job.cover_item_id, undefined, 128)
    : null;

  return (
    <article
      className={styles.card}
      tabIndex={0}
      role="link"
      aria-label={`Open job ${job.name}, ${statusLabel(job.status)}`}
      onClick={() => router.push(href)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          router.push(href);
        }
      }}
    >
      <div className={styles.thumb} aria-hidden>
        {thumbSrc ? (
          /* eslint-disable-next-line @next/next/no-img-element */
          <img src={thumbSrc} alt="" className={styles.thumbImg} loading="lazy" />
        ) : (
          <JobPlaceholderIcon />
        )}
      </div>
      <div className={styles.body}>
        <div className={styles.topRow}>
          <h2 className={styles.title}>{job.name}</h2>
          <span className={`${styles.pill} ${styles[`status_${job.status}`]}`}>
            {statusLabel(job.status)}
          </span>
        </div>
        {subtitle && <p className={styles.subtitle}>{subtitle}</p>}
        <p className={styles.meta}>
          <span className={styles.metaStatus}>{statusLabel(job.status)}</span>
          <span aria-hidden> · </span>
          <span>{updated}</span>
        </p>
      </div>
      {onDelete ? (
        <div className={styles.menuWrap} ref={menuRef}>
          <button
            type="button"
            className={styles.menuBtn}
            aria-label={`Actions for ${job.name}`}
            aria-expanded={menuOpen}
            onClick={(e) => {
              e.stopPropagation();
              setMenuOpen((open) => !open);
            }}
          >
            ⋮
          </button>
          {menuOpen && (
            <div className={styles.menuDropdown}>
              <button
                type="button"
                className={styles.menuDanger}
                onClick={(e) => {
                  e.stopPropagation();
                  setMenuOpen(false);
                  onDelete();
                }}
              >
                Delete job
              </button>
            </div>
          )}
        </div>
      ) : (
        <span className={styles.chevron} aria-hidden>
          ›
        </span>
      )}
    </article>
  );
}

function JobPlaceholderIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
      <rect x="2" y="7" width="20" height="14" rx="2" />
      <path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2" />
    </svg>
  );
}
