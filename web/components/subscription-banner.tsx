"use client";

import Link from "next/link";
import type { Workspace } from "@/lib/types";
import styles from "./subscription-banner.module.css";

type Props = {
  workspace: Workspace;
};

export function SubscriptionBanner({ workspace }: Props) {
  if (workspace.access_mode === "trial") {
    const trialEnd = workspace.trial_ends_at
      ? new Date(workspace.trial_ends_at).toLocaleDateString(undefined, {
          month: "short",
          day: "numeric",
        })
      : null;
    return (
      <div className={`${styles.banner} ${styles.trial}`} role="status">
        <div>
          <p className={styles.title}>Free trial</p>
          <p>
            Single user · up to {workspace.trial_job_limit ?? 3} jobs · up to{" "}
            {workspace.trial_item_limit ?? 50} items per job
            {trialEnd ? ` · ends ${trialEnd}` : ""}.
          </p>
        </div>
        <Link href="/settings">Upgrade</Link>
      </div>
    );
  }

  if (workspace.access_mode === "grace") {
    const days = workspace.grace_days_remaining ?? 0;
    return (
      <div className={`${styles.banner} ${styles.grace}`} role="status">
        <div>
          <p className={styles.title}>Billing issue</p>
          <p>
            Your subscription payment is past due. Sync still works for {days}{" "}
            {days === 1 ? "day" : "days"}. Update billing to avoid read-only mode.
          </p>
        </div>
        <Link href="/settings">Manage subscription</Link>
      </div>
    );
  }

  if (workspace.access_mode === "read_only") {
    return (
      <div className={`${styles.banner} ${styles.locked}`} role="status">
        <div>
          <p className={styles.title}>Your subscription has ended.</p>
          <p>
            Your workspace is currently read-only. Upgrade to continue syncing jobs,
            uploading files, inviting team members, and generating reports.
          </p>
        </div>
        <Link href="/settings">Upgrade</Link>
      </div>
    );
  }

  return null;
}
