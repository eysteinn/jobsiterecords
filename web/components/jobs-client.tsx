"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Job } from "@/lib/api-jobs";
import { useSyncPoll } from "@/hooks/use-sync-poll";
import { useUrlQueryParam, useUrlSetParam } from "@/hooks/use-url-filter-state";
import { formatDateTime } from "@/lib/format";
import { filterJobs, type JobStatus } from "@/lib/search";
import { pollWorkspaceCursor } from "@/lib/sync-cursor";
import { SYNC_POLL } from "@/lib/sync-poll-config";
import { EmptyState, PageShell } from "@/components/page-shell";
import { SearchFilterBar } from "@/components/search-filter-bar";
import { NewJobDrawer } from "@/components/new-job-drawer";
import styles from "./jobs-client.module.css";

const STATUS_CHIPS: { id: JobStatus; label: string }[] = [
  { id: "planning", label: "Planning" },
  { id: "in_progress", label: "In progress" },
  { id: "completed", label: "Completed" },
];

type Props = {
  workspaceId: string;
  jobs: Job[];
};

export function JobsClient({ workspaceId, jobs }: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const searchParams = useSearchParams();
  const [detailed, setDetailed] = useState(() => searchParams.has("status"));
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (searchParams.has("status")) setDetailed(true);
  }, [searchParams]);
  const [query, setQuery] = useUrlQueryParam("q");
  const { values: statusFilter, toggle: toggleStatus } = useUrlSetParam("status");

  const onWorkspaceChanged = useCallback(async () => {
    router.refresh();
  }, [router]);

  useSyncPoll({
    baseIntervalMs: SYNC_POLL.jobsListMs,
    poll: (etag) => pollWorkspaceCursor(workspaceId, etag),
    onChanged: onWorkspaceChanged,
  });

  const filteredJobs = useMemo(
    () =>
      filterJobs(
        jobs,
        query,
        statusFilter.size > 0 ? (statusFilter as ReadonlySet<JobStatus>) : undefined,
      ),
    [jobs, query, statusFilter],
  );

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
        {jobs.length > 0 && (
          <SearchFilterBar
            query={query}
            onQueryChange={setQuery}
            placeholder="Search jobs by name, client, address, or number…"
            detailed={detailed}
            onDetailedChange={setDetailed}
            chips={STATUS_CHIPS}
            activeChipIds={statusFilter}
            onToggleChip={toggleStatus}
            shownCount={filteredJobs.length}
            totalCount={jobs.length}
            inputRef={searchRef}
          />
        )}
        {jobs.length === 0 ? (
          <EmptyState
            title="No jobs in this workspace yet"
            description="Create a job here or capture one on your phone while signed in to your workspace."
          />
        ) : filteredJobs.length === 0 ? (
          <EmptyState
            title="No jobs match your search"
            description="Try a different term or clear filters to see all jobs."
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
                {filteredJobs.map((job) => {
                  const href = `/jobs/${job.id}`;
                  return (
                    <tr
                      key={job.id}
                      className={styles.row}
                      tabIndex={0}
                      role="link"
                      aria-label={`Open job ${job.name}`}
                      onClick={() => router.push(href)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" || e.key === " ") {
                          e.preventDefault();
                          router.push(href);
                        }
                      }}
                    >
                      <td>
                        <span className={styles.jobName}>{job.name}</span>
                        {job.address && <div className={styles.sub}>{job.address}</div>}
                      </td>
                      <td>{job.client_name || "—"}</td>
                      <td>
                        <span className={styles.pill}>{job.status.replace("_", " ")}</span>
                      </td>
                      <td>{formatDateTime(job.last_activity_at ?? job.updated_at)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </PageShell>
      {open && <NewJobDrawer workspaceId={workspaceId} onClose={() => setOpen(false)} />}
    </>
  );
}
