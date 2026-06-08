"use client";

import type { Job } from "@/lib/api-jobs";
import type { JobStatus } from "@/lib/search";
import styles from "./mobile-status-filters.module.css";

type Chip = {
  id: JobStatus | "all";
  label: string;
  count: number;
};

type Props = {
  jobs: Job[];
  activeStatus: ReadonlySet<JobStatus>;
  onSelect: (status: JobStatus | "all") => void;
};

export function MobileStatusFilters({ jobs, activeStatus, onSelect }: Props) {
  const counts = {
    all: jobs.length,
    planning: jobs.filter((j) => j.status === "planning").length,
    in_progress: jobs.filter((j) => j.status === "in_progress").length,
    completed: jobs.filter((j) => j.status === "completed").length,
  };

  const chips: Chip[] = [
    { id: "all", label: "All", count: counts.all },
    { id: "in_progress", label: "In Progress", count: counts.in_progress },
    { id: "completed", label: "Completed", count: counts.completed },
    { id: "planning", label: "Planning", count: counts.planning },
  ];

  const activeId: JobStatus | "all" =
    activeStatus.size === 1 ? ([...activeStatus][0] as JobStatus) : "all";

  return (
    <div className={styles.row} role="group" aria-label="Filter by status">
      {chips.map((chip) => {
        const active = activeId === chip.id;
        return (
          <button
            key={chip.id}
            type="button"
            className={active ? styles.chipActive : styles.chip}
            aria-pressed={active}
            onClick={() => onSelect(chip.id)}
          >
            {chip.label}
            <span className={active ? styles.badgeActive : styles.badge}>{chip.count}</span>
          </button>
        );
      })}
    </div>
  );
}
