"use client";

import { formatRelativeTime } from "@/lib/format";
import styles from "./mobile-sync-status.module.css";

type Props = {
  workspaceName: string;
  lastSyncedAt: Date | null;
  syncing?: boolean;
  failed?: boolean;
  onRetry?: () => void;
};

export function MobileSyncStatus({
  workspaceName,
  lastSyncedAt,
  syncing = false,
  failed = false,
  onRetry,
}: Props) {
  let statusText: string;
  if (syncing) {
    statusText = "Syncing…";
  } else if (failed) {
    statusText = "Sync failed · Tap to retry";
  } else if (lastSyncedAt) {
    statusText = `Synced ${formatRelativeTime(lastSyncedAt.toISOString())}`;
  } else {
    statusText = "Synced";
  }

  const content = (
    <>
      <span className={styles.workspace}>{workspaceName}</span>
      <span aria-hidden> · </span>
      <span className={failed ? styles.failed : styles.status}>{statusText}</span>
    </>
  );

  if (failed && onRetry) {
    return (
      <button type="button" className={styles.bar} onClick={onRetry} aria-label="Retry sync">
        {content}
      </button>
    );
  }

  return (
    <p className={styles.bar} role="status">
      {content}
    </p>
  );
}
