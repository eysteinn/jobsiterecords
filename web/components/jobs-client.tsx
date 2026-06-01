"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import Link from "next/link";
import type { Job } from "@/lib/api-jobs";
import { formatDateTime } from "@/lib/format";
import { EmptyState, PageShell } from "@/components/page-shell";
import { NewJobDrawer } from "@/components/new-job-drawer";
import styles from "./jobs-client.module.css";

type Props = {
  workspaceId: string;
  jobs: Job[];
};

export function JobsClient({ workspaceId, jobs }: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  async function refresh() {
    setRefreshing(true);
    router.refresh();
    setRefreshing(false);
  }

  return (
    <>
      <PageShell
        title="Jobs"
        subtitle="Synced job records for this workspace"
        action={
          <div style={{ display: "flex", gap: "8px" }}>
            <button type="button" className={styles.secondary} onClick={refresh} disabled={refreshing}>
              {refreshing ? "Refreshing…" : "Refresh"}
            </button>
            <button type="button" className={styles.primary} onClick={() => setOpen(true)}>
              + New job
            </button>
          </div>
        }
      >
        {jobs.length === 0 ? (
          <EmptyState
            title="No jobs in this workspace yet"
            description="Create a job here or capture one on your phone while signed in to your workspace."
          />
        ) : (
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Job</th>
                  <th>Client</th>
                  <th>Status</th>
                  <th>Updated</th>
                </tr>
              </thead>
              <tbody>
                {jobs.map((job) => (
                  <tr key={job.id}>
                    <td>
                      <Link href={`/jobs/${job.id}`} className={styles.jobLink}>
                        {job.name}
                      </Link>
                      {job.address && <div className={styles.sub}>{job.address}</div>}
                    </td>
                    <td>{job.client_name || "—"}</td>
                    <td>
                      <span className={styles.pill}>{job.status.replace("_", " ")}</span>
                    </td>
                    <td>{formatDateTime(job.updated_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </PageShell>
      {open && <NewJobDrawer workspaceId={workspaceId} onClose={() => setOpen(false)} />}
    </>
  );
}
