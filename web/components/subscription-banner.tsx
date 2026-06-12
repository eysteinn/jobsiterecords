"use client";

import Link from "next/link";
import type { Workspace } from "@/lib/types";
import styles from "./subscription-banner.module.css";

type Props = {
  workspace: Workspace;
};

export function SubscriptionBanner({ workspace }: Props) {
  if (!workspace.has_subscription) return null;
  if (!["past_due", "canceled"].includes(workspace.subscription_status)) return null;

  const message =
    workspace.subscription_status === "past_due"
      ? "Your subscription payment is past due. Synced jobs are read-only until billing is updated."
      : "Your subscription is canceled. Synced jobs are read-only until you reactivate billing.";

  return (
    <div className={styles.banner} role="status">
      <p>{message}</p>
      <Link href="/settings">Manage subscription</Link>
    </div>
  );
}
