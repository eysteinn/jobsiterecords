"use client";

import { useState, useEffect, useCallback } from "react";
import { PageShell } from "@/components/page-shell";
import type { Job } from "@/lib/api-jobs";
import type { Report } from "@/lib/api-reports";
import styles from "./reports-client.module.css";

type Props = {
  workspaceId: string;
  jobs: Job[];
  initialReports: Report[];
};

export function ReportsClient({ workspaceId, jobs, initialReports }: Props) {
  const [reports, setReports] = useState<Report[]>(initialReports);
  const [showForm, setShowForm] = useState(false);
  const [creating, setCreating] = useState(false);
  const [formError, setFormError] = useState("");

  // Form fields
  const [jobId, setJobId] = useState("");
  const [title, setTitle] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [includePhotos, setIncludePhotos] = useState(true);
  const [includeNotes, setIncludeNotes] = useState(true);
  const [includeVoice, setIncludeVoice] = useState(true);
  const [includeFiles, setIncludeFiles] = useState(true);

  const refresh = useCallback(async () => {
    const res = await fetch(`/api/workspaces/${workspaceId}/reports`);
    if (res.ok) {
      const data = await res.json();
      setReports(data.reports ?? []);
    }
  }, [workspaceId]);

  // Poll while any report is in-progress
  const hasActive = reports.some(
    (r) => r.status === "queued" || r.status === "rendering",
  );
  useEffect(() => {
    if (!hasActive) return;
    const id = setInterval(refresh, 3000);
    return () => clearInterval(id);
  }, [hasActive, refresh]);

  function handleJobChange(id: string) {
    setJobId(id);
    if (id) {
      const job = jobs.find((j) => j.id === id);
      if (job) {
        const today = new Date().toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric",
        });
        setTitle(`${job.name} — ${today}`);
      }
    }
  }

  function resetForm() {
    setJobId("");
    setTitle("");
    setDateFrom("");
    setDateTo("");
    setIncludePhotos(true);
    setIncludeNotes(true);
    setIncludeVoice(true);
    setIncludeFiles(true);
    setFormError("");
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!jobId || !title.trim()) return;
    setCreating(true);
    setFormError("");
    try {
      const res = await fetch(`/api/workspaces/${workspaceId}/reports`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          job_id: jobId,
          title: title.trim(),
          date_from: dateFrom || undefined,
          date_to: dateTo || undefined,
          include_photos: includePhotos,
          include_notes: includeNotes,
          include_voice: includeVoice,
          include_files: includeFiles,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setFormError(data.message ?? "Failed to create report");
        return;
      }
      setReports((prev) => [data.report, ...prev]);
      setShowForm(false);
      resetForm();
    } catch {
      setFormError("Network error — please try again");
    } finally {
      setCreating(false);
    }
  }

  const jobMap = Object.fromEntries(jobs.map((j) => [j.id, j]));

  const newReportBtn = (
    <button
      className={styles.primary}
      onClick={() => {
        setShowForm((v) => !v);
        if (showForm) resetForm();
      }}
    >
      {showForm ? "Cancel" : "+ New PDF report"}
    </button>
  );

  return (
    <>
      {/* ── Desktop ── */}
      <div className={styles.desktopOnly}>
        <PageShell
          title="Reports"
          subtitle="Generate PDF reports from job records."
          action={newReportBtn}
        >
          {showForm && (
            <CreateForm
              jobs={jobs}
              jobId={jobId}
              title={title}
              dateFrom={dateFrom}
              dateTo={dateTo}
              includePhotos={includePhotos}
              includeNotes={includeNotes}
              includeVoice={includeVoice}
              includeFiles={includeFiles}
              creating={creating}
              error={formError}
              onJobChange={handleJobChange}
              onTitleChange={setTitle}
              onDateFromChange={setDateFrom}
              onDateToChange={setDateTo}
              onIncludePhotosChange={setIncludePhotos}
              onIncludeNotesChange={setIncludeNotes}
              onIncludeVoiceChange={setIncludeVoice}
              onIncludeFilesChange={setIncludeFiles}
              onSubmit={handleCreate}
              onCancel={() => { setShowForm(false); resetForm(); }}
            />
          )}

          {reports.length === 0 && !showForm ? (
            <div className={styles.empty}>
              <h2>No reports yet</h2>
              <p>Click &ldquo;+ New PDF report&rdquo; to generate your first report.</p>
            </div>
          ) : (
            reports.length > 0 && (
              <div className={styles.tableWrap}>
                <table className={styles.table}>
                  <thead>
                    <tr>
                      <th>Title</th>
                      <th>Job</th>
                      <th>Status</th>
                      <th>Created</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {reports.map((r) => (
                      <ReportRow key={r.id} report={r} job={jobMap[r.job_id]} />
                    ))}
                  </tbody>
                </table>
              </div>
            )
          )}
        </PageShell>
      </div>

      {/* ── Mobile ── */}
      <div className={styles.mobileOnly}>
        <div className={styles.mobilePage}>
          <div className={styles.mobileHeader}>
            <div className={styles.mobileHeaderTop}>
              <h1 className={styles.mobileTitle}>Reports</h1>
              <button
                className={styles.primary}
                onClick={() => {
                  setShowForm((v) => !v);
                  if (showForm) resetForm();
                }}
              >
                {showForm ? "Cancel" : "+ New"}
              </button>
            </div>
          </div>

          {showForm && (
            <CreateForm
              jobs={jobs}
              jobId={jobId}
              title={title}
              dateFrom={dateFrom}
              dateTo={dateTo}
              includePhotos={includePhotos}
              includeNotes={includeNotes}
              includeVoice={includeVoice}
              includeFiles={includeFiles}
              creating={creating}
              error={formError}
              onJobChange={handleJobChange}
              onTitleChange={setTitle}
              onDateFromChange={setDateFrom}
              onDateToChange={setDateTo}
              onIncludePhotosChange={setIncludePhotos}
              onIncludeNotesChange={setIncludeNotes}
              onIncludeVoiceChange={setIncludeVoice}
              onIncludeFilesChange={setIncludeFiles}
              onSubmit={handleCreate}
              onCancel={() => { setShowForm(false); resetForm(); }}
            />
          )}

          {reports.length === 0 && !showForm ? (
            <div className={styles.mobileEmpty}>
              <h2>No reports yet</h2>
              <p>Tap &ldquo;+ New&rdquo; to generate your first report.</p>
            </div>
          ) : (
            <div className={styles.cardList}>
              {reports.map((r) => (
                <ReportCard key={r.id} report={r} job={jobMap[r.job_id]} />
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  );
}

// ── Create form (shared between desktop & mobile) ──

type CreateFormProps = {
  jobs: Job[];
  jobId: string;
  title: string;
  dateFrom: string;
  dateTo: string;
  includePhotos: boolean;
  includeNotes: boolean;
  includeVoice: boolean;
  includeFiles: boolean;
  creating: boolean;
  error: string;
  onJobChange: (id: string) => void;
  onTitleChange: (v: string) => void;
  onDateFromChange: (v: string) => void;
  onDateToChange: (v: string) => void;
  onIncludePhotosChange: (v: boolean) => void;
  onIncludeNotesChange: (v: boolean) => void;
  onIncludeVoiceChange: (v: boolean) => void;
  onIncludeFilesChange: (v: boolean) => void;
  onSubmit: (e: React.FormEvent) => void;
  onCancel: () => void;
};

function CreateForm({
  jobs, jobId, title, dateFrom, dateTo,
  includePhotos, includeNotes, includeVoice, includeFiles,
  creating, error,
  onJobChange, onTitleChange, onDateFromChange, onDateToChange,
  onIncludePhotosChange, onIncludeNotesChange, onIncludeVoiceChange, onIncludeFilesChange,
  onSubmit, onCancel,
}: CreateFormProps) {
  return (
    <form className={styles.form} onSubmit={onSubmit}>
      <div className={styles.formGrid}>
        <label className={styles.formField}>
          <span className={styles.label}>Job</span>
          <select
            className={styles.select}
            value={jobId}
            onChange={(e) => onJobChange(e.target.value)}
            required
          >
            <option value="">Select a job…</option>
            {jobs.map((j) => (
              <option key={j.id} value={j.id}>
                {j.name}{j.client_name ? ` — ${j.client_name}` : ""}
              </option>
            ))}
          </select>
        </label>

        <label className={styles.formField}>
          <span className={styles.label}>Report title</span>
          <input
            className={styles.input}
            type="text"
            value={title}
            onChange={(e) => onTitleChange(e.target.value)}
            placeholder="e.g. Client handoff — Kitchen reno"
            required
          />
        </label>

        <div className={styles.dateRow}>
          <label className={styles.formField}>
            <span className={styles.label}>From (optional)</span>
            <input
              className={styles.input}
              type="date"
              value={dateFrom}
              onChange={(e) => onDateFromChange(e.target.value)}
            />
          </label>
          <label className={styles.formField}>
            <span className={styles.label}>To (optional)</span>
            <input
              className={styles.input}
              type="date"
              value={dateTo}
              onChange={(e) => onDateToChange(e.target.value)}
            />
          </label>
        </div>

        <div className={styles.formField}>
          <span className={styles.label}>Include</span>
          <div className={styles.checkRow}>
            {[
              ["Photos", includePhotos, onIncludePhotosChange],
              ["Notes", includeNotes, onIncludeNotesChange],
              ["Voice", includeVoice, onIncludeVoiceChange],
              ["Files", includeFiles, onIncludeFilesChange],
            ].map(([lbl, val, fn]) => (
              <label key={lbl as string} className={styles.checkLabel}>
                <input
                  type="checkbox"
                  checked={val as boolean}
                  onChange={(e) => (fn as (v: boolean) => void)(e.target.checked)}
                />
                {lbl as string}
              </label>
            ))}
          </div>
        </div>
      </div>

      {error && <p className={styles.formError}>{error}</p>}

      <div className={styles.formActions}>
        <button type="button" className={styles.secondary} onClick={onCancel}>
          Cancel
        </button>
        <button type="submit" className={styles.primary} disabled={creating || !jobId || !title}>
          {creating ? "Generating…" : "Generate PDF"}
        </button>
      </div>
    </form>
  );
}

// ── Desktop table row ──

function ReportRow({ report, job }: { report: Report; job?: Job }) {
  return (
    <tr>
      <td>
        <div className={styles.reportName}>{report.title}</div>
      </td>
      <td>
        <div>{job?.name ?? report.job_id}</div>
        {job?.client_name && <div className={styles.sub}>{job.client_name}</div>}
      </td>
      <td>
        <StatusBadge status={report.status} />
        {report.error_msg && (
          <div className={styles.errorMsg} title={report.error_msg}>
            {report.error_msg.slice(0, 60)}{report.error_msg.length > 60 ? "…" : ""}
          </div>
        )}
      </td>
      <td className={styles.muted}>{formatDate(report.created_at)}</td>
      <td className={styles.rowActions}>
        {report.status === "ready" && (
          <a
            href={`/api/reports/${report.id}/download`}
            target="_blank"
            rel="noopener noreferrer"
            className={styles.downloadBtn}
          >
            Download
          </a>
        )}
      </td>
    </tr>
  );
}

// ── Mobile card ──

function ReportCard({ report, job }: { report: Report; job?: Job }) {
  return (
    <div className={styles.card}>
      <div className={styles.cardHeader}>
        <div className={styles.reportName}>{report.title}</div>
        <StatusBadge status={report.status} />
      </div>
      <div className={styles.sub}>{job?.name ?? report.job_id}</div>
      {report.error_msg && (
        <div className={styles.errorMsg}>{report.error_msg.slice(0, 80)}</div>
      )}
      <div className={styles.cardFooter}>
        <span className={styles.muted}>{formatDate(report.created_at)}</span>
        {report.status === "ready" && (
          <a
            href={`/api/reports/${report.id}/download`}
            target="_blank"
            rel="noopener noreferrer"
            className={styles.downloadBtn}
          >
            Download
          </a>
        )}
      </div>
    </div>
  );
}

// ── Status badge ──

function StatusBadge({ status }: { status: Report["status"] }) {
  return (
    <span className={`${styles.pill} ${styles[`status_${status}`]}`}>
      {status === "queued" && "⏳ Queued"}
      {status === "rendering" && "⚙ Rendering…"}
      {status === "ready" && "✓ Ready"}
      {status === "failed" && "✗ Failed"}
    </span>
  );
}

// ── Helpers ──

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}
