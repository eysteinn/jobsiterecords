"use client";

import { useRouter } from "next/navigation";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import type { Job } from "@/lib/api-jobs";
import { buildJobPutPayload, jobToFormValues } from "@/lib/job-form";
import styles from "./job-form.module.css";

const STATUS_OPTIONS: { value: Job["status"]; label: string }[] = [
  { value: "planning", label: "Planning" },
  { value: "in_progress", label: "In progress" },
  { value: "completed", label: "Completed" },
];

type CreateProps = {
  mode: "create";
  workspaceId: string;
  onClose: () => void;
};

type EditProps = {
  mode: "edit";
  job: Job;
  onClose: () => void;
  onSaved: (job: Job) => void;
};

type Props = CreateProps | EditProps;

export function JobFormDrawer(props: Props) {
  const router = useRouter();
  const isEdit = props.mode === "edit";
  const job = isEdit ? props.job : null;
  const initial = useMemo(
    () => (job ? jobToFormValues(job) : {
      name: "",
      client_name: "",
      address: "",
      job_number: "",
      status: "in_progress" as const,
      start_date: "",
      end_date: "",
      notes: "",
    }),
    [job],
  );

  const [name, setName] = useState(initial.name);
  const [clientName, setClientName] = useState(initial.client_name);
  const [address, setAddress] = useState(initial.address);
  const [jobNumber, setJobNumber] = useState(initial.job_number);
  const [status, setStatus] = useState<Job["status"]>(initial.status);
  const [startDate, setStartDate] = useState(initial.start_date);
  const [endDate, setEndDate] = useState(initial.end_date);
  const [notes, setNotes] = useState(initial.notes);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const dirty =
    name !== initial.name ||
    clientName !== initial.client_name ||
    address !== initial.address ||
    jobNumber !== initial.job_number ||
    status !== initial.status ||
    startDate !== initial.start_date ||
    endDate !== initial.end_date ||
    notes !== initial.notes;

  const requestClose = useCallback(() => {
    if (saving) return;
    if (dirty && !window.confirm("Discard unsaved changes?")) return;
    props.onClose();
  }, [dirty, props, saving]);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") requestClose();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [requestClose]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      if (isEdit) {
        const res = await fetch(`/api/jobs/${props.job.id}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(
            buildJobPutPayload(props.job, {
              name,
              client_name: clientName,
              address,
              job_number: jobNumber,
              status,
              start_date: startDate,
              end_date: endDate,
              notes,
            }),
          ),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.message || "Could not save job");
        props.onSaved(data as Job);
        router.refresh();
        props.onClose();
        return;
      }

      const id = crypto.randomUUID();
      const now = new Date().toISOString();
      const res = await fetch(`/api/workspaces/${props.workspaceId}/jobs/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          workspace_id: props.workspaceId,
          name: name.trim(),
          client_name: clientName.trim() || null,
          address: address.trim() || null,
          job_number: jobNumber.trim() || null,
          status,
          start_date: startDate || null,
          end_date: endDate || null,
          notes: notes.trim() || null,
          created_at: now,
          updated_at: now,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || "Could not create job");
      router.push(`/jobs/${id}`);
      router.refresh();
      props.onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : isEdit ? "Could not save job" : "Could not create job");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className={styles.backdrop} onClick={requestClose}>
      <aside
        className={styles.drawer}
        role="dialog"
        aria-modal="true"
        aria-labelledby="job-form-title"
        onClick={(e) => e.stopPropagation()}
      >
        <header>
          <h2 id="job-form-title">{isEdit ? "Edit job details" : "New job"}</h2>
          <button type="button" onClick={requestClose} aria-label="Close">
            ×
          </button>
        </header>
        <form onSubmit={onSubmit} className={styles.form}>
          <div className={styles.formBody}>
            <label>
              Job name
              <input
                required
                autoFocus
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Kitchen remodel"
              />
            </label>
            <label>
              Client
              <input
                value={clientName}
                onChange={(e) => setClientName(e.target.value)}
                placeholder="Client name (optional)"
              />
            </label>
            <label>
              Site address
              <input
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Street address (optional)"
              />
            </label>
            <label>
              Job number
              <input
                value={jobNumber}
                onChange={(e) => setJobNumber(e.target.value)}
                placeholder="Optional"
              />
            </label>
            <label>
              Status
              <select value={status} onChange={(e) => setStatus(e.target.value as Job["status"])}>
                {STATUS_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
            <div className={styles.dateRow}>
              <label>
                Start date
                <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
              </label>
              <label>
                End date
                <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
              </label>
            </div>
            <label>
              Notes
              <textarea
                rows={3}
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Optional details about the job"
              />
            </label>
            {error && <p className={styles.error}>{error}</p>}
          </div>
          <div className={styles.formFooter}>
            <button type="button" className={styles.secondary} onClick={requestClose} disabled={saving}>
              Cancel
            </button>
            <button type="submit" className={styles.primary} disabled={saving || (isEdit && !dirty)}>
              {saving ? (isEdit ? "Saving…" : "Creating…") : isEdit ? "Save changes" : "Create job"}
            </button>
          </div>
        </form>
      </aside>
    </div>
  );
}
