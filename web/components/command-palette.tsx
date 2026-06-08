"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Job } from "@/lib/api-jobs";
import { fuzzyScore } from "@/lib/search";
import styles from "./command-palette.module.css";

type Props = {
  open: boolean;
  onClose: () => void;
  workspaceId?: string;
};

type PaletteItem = {
  id: string;
  label: string;
  hint?: string;
  href?: string;
  action?: () => void;
};

const NAV_ITEMS: PaletteItem[] = [
  { id: "nav-jobs", label: "Go to Jobs", href: "/jobs" },
  { id: "nav-reports", label: "Go to Reports", href: "/reports" },
  { id: "nav-team", label: "Go to Team", href: "/team" },
  { id: "nav-settings", label: "Go to Settings", href: "/settings" },
];

export function CommandPalette({ open, onClose, workspaceId }: Props) {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState("");
  const [jobs, setJobs] = useState<Job[]>([]);
  const [loadingJobs, setLoadingJobs] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    if (!open) {
      setQuery("");
      setActiveIndex(0);
      return;
    }
    inputRef.current?.focus();
  }, [open]);

  useEffect(() => {
    if (!open || !workspaceId) return;
    let cancelled = false;
    setLoadingJobs(true);
    fetch(`/api/workspaces/${workspaceId}/jobs`)
      .then((res) => res.json())
      .then((data: { jobs?: Job[] }) => {
        if (!cancelled) setJobs(data.jobs ?? []);
      })
      .catch(() => {
        if (!cancelled) setJobs([]);
      })
      .finally(() => {
        if (!cancelled) setLoadingJobs(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, workspaceId]);

  const items = useMemo(() => {
    const trimmed = query.trim();
    const results: PaletteItem[] = [];

    if (trimmed) {
      const scoredJobs = jobs
        .map((job) => {
          const text = [job.name, job.client_name, job.address, job.job_number]
            .filter(Boolean)
            .join(" ");
          return { job, score: fuzzyScore(text, trimmed) };
        })
        .filter((entry) => entry.score > 0)
        .sort((a, b) => b.score - a.score)
        .slice(0, 8);

      for (const { job } of scoredJobs) {
        const hint = [job.client_name, job.address].filter(Boolean).join(" · ");
        results.push({
          id: `job-${job.id}`,
          label: job.name,
          hint: hint || undefined,
          href: `/jobs/${job.id}`,
        });
      }
    }

    const navMatches = NAV_ITEMS.filter((item) =>
      trimmed ? fuzzyScore(item.label, trimmed) > 0 : true,
    );
    results.push(...navMatches);

    results.push({
      id: "sign-out",
      label: "Sign out",
      action: async () => {
        await fetch("/api/auth/logout", { method: "POST" });
        router.push("/login");
        router.refresh();
      },
    });

    return results;
  }, [jobs, query, router]);

  useEffect(() => {
    setActiveIndex(0);
  }, [query, items.length]);

  const runItem = useCallback(
    (item: PaletteItem) => {
      onClose();
      if (item.action) {
        void item.action();
        return;
      }
      if (item.href) router.push(item.href);
    },
    [onClose, router],
  );

  useEffect(() => {
    if (!open) return;
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        onClose();
        return;
      }
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setActiveIndex((i) => Math.min(i + 1, items.length - 1));
        return;
      }
      if (e.key === "ArrowUp") {
        e.preventDefault();
        setActiveIndex((i) => Math.max(i - 1, 0));
        return;
      }
      if (e.key === "Enter" && items[activeIndex]) {
        e.preventDefault();
        runItem(items[activeIndex]);
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose, items, activeIndex, runItem]);

  if (!open) return null;

  return (
    <div className={styles.backdrop} onClick={onClose} role="presentation">
      <div
        className={styles.panel}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-label="Command palette"
      >
        <input
          ref={inputRef}
          className={styles.input}
          placeholder="Search jobs or jump to a page…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          aria-label="Search"
        />
        <ul className={styles.list} role="listbox">
          {items.map((item, index) => (
            <li
              key={item.id}
              role="option"
              aria-selected={index === activeIndex}
              className={index === activeIndex ? styles.itemActive : undefined}
              onMouseEnter={() => setActiveIndex(index)}
              onClick={() => runItem(item)}
            >
              <span className={styles.itemLabel}>{item.label}</span>
              {item.hint && <span className={styles.itemHint}>{item.hint}</span>}
            </li>
          ))}
          {loadingJobs && query.trim() && items.length === 0 && (
            <li className={styles.empty}>Loading jobs…</li>
          )}
          {!loadingJobs && query.trim() && items.every((item) => item.id.startsWith("nav-") || item.id === "sign-out") && (
            <li className={styles.empty}>No matching jobs</li>
          )}
        </ul>
        <p className={styles.hint}>↑↓ to navigate · Enter to open · Esc to close</p>
      </div>
    </div>
  );
}
