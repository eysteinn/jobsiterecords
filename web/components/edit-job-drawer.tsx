"use client";

import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import type { Job } from "@/lib/api-jobs";
import { buildJobPutPayload, jobToFormValues } from "@/lib/job-form";
import styles from "./job-form.module.css";

const STATUS_OPTIONS: { value: Job["status"]; label: string }[] = [
  { value: "planning", label: "Planning" },
  { value: "in_progress", label: "In progress" },
  { value: "completed", label: "Completed" },
];

type Props = {
  job: Job;
  onClose: () => void;
  onSaved: (job: Job) => void;
};

export function EditJobDrawer({ job, onClose, onSaved }: Props) {
  const router = useRouter();
  const initial = jobToFormValues(job);
  const [name, setName] = useState(initial.name);
  const [clientName, setClientName] = useState(initial.client_name);
  const [address, setAddress] = useState(initial.address);
  const [jobNumber, setJobNumber] = useState(initial.job_number);
  const [status, setStatus] = useState(initial.status);
  const [startDate, setStartDate] = useState(initial.start_date);
  const [endDate, setEndDate] = useState(initial.end_date);
  const [notes, setNotes] = useState(initial.notes);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const res = await fetch(`/api/jobs/${job.id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(
          buildJobPutPayload(job, {
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
      onSaved(data as Job);
      router.refresh();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save job");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className={styles.backdrop} onClick={onClose}>
      <aside className={styles.drawer} onClick={(e) => e.stopPropagation()}>
        <header>
          <h2>Edit job</h2>
          <button type="button" onClick={onClose} aria-label="Close">
            ×
          </button>
        </header>
        <form onSubmit={onSubmit} className={styles.form}>
          <label>
            Job name
            <input required value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label>
            Client
            <input value={clientName} onChange={(e) => setClientName(e.target.value)} />
          </label>
          <label>
            Address
            <input value={address} onChange={(e) => setAddress(e.target.value)} />
          </label>
          <label>
            Job number
            <input value={jobNumber} onChange={(e) => setJobNumber(e.target.value)} />
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
            <textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
          </label>
          {error && <p className={styles.error}>{error}</p>}
          <button type="submit" className={styles.primary} disabled={saving}>
            {saving ? "Saving…" : "Save changes"}
          </button>
        </form>
      </aside>
    </div>
  );
}
