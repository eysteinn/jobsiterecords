"use client";

import Link from "next/link";
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
import { MobileJobCard } from "@/components/mobile-job-card";
import { MobileStatusFilters } from "@/components/mobile-status-filters";
import { MobileSyncStatus } from "@/components/mobile-sync-status";
import { MobileFilterSheet } from "@/components/mobile-filter-sheet";
import styles from "./jobs-client.module.css";

const STATUS_CHIPS: { id: JobStatus; label: string }[] = [
  { id: "planning", label: "Planning" },
  { id: "in_progress", label: "In progress" },
  { id: "completed", label: "Completed" },
];

type Props = {
  workspaceId: string;
  workspaceName: string;
  userEmail: string;
  jobs: Job[];
};

export function JobsClient({ workspaceId, workspaceName, userEmail, jobs }: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [filterSheetOpen, setFilterSheetOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [lastSyncedAt, setLastSyncedAt] = useState<Date | null>(() => new Date());
  const searchParams = useSearchParams();
  const [detailed, setDetailed] = useState(() => searchParams.has("status"));
  const searchRef = useRef<HTMLInputElement>(null);
  const accountRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (searchParams.has("status")) setDetailed(true);
  }, [searchParams]);

  useEffect(() => {
    if (!accountOpen) return;
    function onPointerDown(e: PointerEvent) {
      if (accountRef.current && !accountRef.current.contains(e.target as Node)) {
        setAccountOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [accountOpen]);

  const [query, setQuery] = useUrlQueryParam("q");
  const { values: statusFilter, toggle: toggleStatus, setValues: setStatusFilter } = useUrlSetParam("status");

  const onWorkspaceChanged = useCallback(async () => {
    setLastSyncedAt(new Date());
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
    try {
      router.refresh();
      setLastSyncedAt(new Date());
    } finally {
      setRefreshing(false);
    }
  }

  function handleMobileStatusSelect(status: JobStatus | "all") {
    if (status === "all") {
      setStatusFilter(new Set());
    } else {
      setStatusFilter(new Set([status]));
    }
  }

  async function signOut() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
    router.refresh();
  }

  return (
    <>
      {/* Mobile layout */}
      <div className={`${styles.mobilePage} mobileOnly`}>
        <header className={styles.mobileHeader}>
          <div className={styles.mobileHeaderTop}>
            <h1 className={styles.mobileTitle}>Jobs</h1>
            <div className={styles.mobileHeaderActions}>
              <button
                type="button"
                className={styles.iconBtn}
                onClick={refresh}
                disabled={refreshing}
                aria-label={refreshing ? "Refreshing" : "Refresh jobs"}
              >
                <RefreshIcon spinning={refreshing} />
              </button>
              <div className={styles.accountMenu} ref={accountRef}>
                <button
                  type="button"
                  className={styles.iconBtn}
                  onClick={() => setAccountOpen((v) => !v)}
                  aria-expanded={accountOpen}
                  aria-label="Account menu"
                >
                  <AccountIcon />
                </button>
                {accountOpen && (
                  <div className={styles.accountDropdown}>
                    <p className={styles.accountEmail}>{userEmail}</p>
                    <Link href="/settings" onClick={() => setAccountOpen(false)}>
                      Account settings
                    </Link>
                    <button type="button" onClick={signOut}>
                      Sign out
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
          <button type="button" className={styles.workspaceBtn} aria-label={`Workspace: ${workspaceName}`}>
            <span className={styles.workspaceName}>{workspaceName}</span>
            <span aria-hidden>▾</span>
          </button>
        </header>

        {jobs.length > 0 && (
          <div className={styles.mobileSearchSection}>
            <SearchFilterBar
              query={query}
              onQueryChange={setQuery}
              placeholder="Search jobs"
              detailed={detailed}
              onDetailedChange={(next) => {
                if (next) setFilterSheetOpen(true);
                else setDetailed(false);
              }}
              chips={STATUS_CHIPS}
              activeChipIds={statusFilter}
              onToggleChip={toggleStatus}
              shownCount={filteredJobs.length}
              totalCount={jobs.length}
              inputRef={searchRef}
              mobile
              onOpenFilterSheet={() => setFilterSheetOpen(true)}
            />
            <MobileStatusFilters
              jobs={jobs}
              activeStatus={statusFilter as ReadonlySet<JobStatus>}
              onSelect={handleMobileStatusSelect}
            />
          </div>
        )}

        {jobs.length === 0 ? (
          <div className={styles.mobileEmpty}>
            <h2>No jobs yet</h2>
            <p>Create your first job to start organizing photos, notes, and files.</p>
            <button type="button" className={styles.fab} onClick={() => setOpen(true)}>
              + New job
            </button>
          </div>
        ) : filteredJobs.length === 0 ? (
          <EmptyState
            title="No jobs match your search"
            description="Try a different term or clear filters to see all jobs."
          />
        ) : (
          <div className={styles.cardList}>
            {filteredJobs.map((job) => (
              <MobileJobCard key={job.id} job={job} />
            ))}
          </div>
        )}

        <MobileSyncStatus
          workspaceName={workspaceName}
          lastSyncedAt={lastSyncedAt}
          syncing={refreshing}
          onRetry={refresh}
        />

        {jobs.length > 0 && (
          <button
            type="button"
            className={styles.fabSticky}
            onClick={() => setOpen(true)}
            aria-label="New job"
          >
            + New job
          </button>
        )}

        <MobileFilterSheet
          open={filterSheetOpen}
          onClose={() => {
            setFilterSheetOpen(false);
            setDetailed(false);
          }}
          title="Filter jobs"
          chips={STATUS_CHIPS}
          activeChipIds={statusFilter}
          onToggleChip={toggleStatus}
          onClear={() => setStatusFilter(new Set())}
        />
      </div>

      {/* Desktop layout */}
      <div className="desktopOnly">
        <PageShell
          title="Jobs"
          subtitle="Synced job records for this workspace"
          action={
            <div className={styles.desktopActions}>
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
              placeholder="Search jobs"
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
                          <span className={`${styles.pill} ${styles[`status_${job.status}`]}`}>
                            {job.status.replace(/_/g, " ")}
                          </span>
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
      </div>

      {open && <NewJobDrawer workspaceId={workspaceId} onClose={() => setOpen(false)} />}
    </>
  );
}

function RefreshIcon({ spinning }: { spinning: boolean }) {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      aria-hidden
      className={spinning ? styles.spin : undefined}
    >
      <path d="M21 12a9 9 0 1 1-3-6.7" />
      <path d="M21 3v6h-6" />
    </svg>
  );
}

function AccountIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}
