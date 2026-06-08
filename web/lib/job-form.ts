import type { Job } from "@/lib/api-jobs";

export type JobFormValues = {
  name: string;
  client_name: string;
  address: string;
  job_number: string;
  status: Job["status"];
  start_date: string;
  end_date: string;
  notes: string;
};

export function jobToFormValues(job: Job): JobFormValues {
  return {
    name: job.name,
    client_name: job.client_name ?? "",
    address: job.address ?? "",
    job_number: job.job_number ?? "",
    status: job.status,
    start_date: job.start_date ?? "",
    end_date: job.end_date ?? "",
    notes: job.notes ?? "",
  };
}

export function buildJobPutPayload(job: Job, values: Partial<JobFormValues>) {
  const merged = { ...jobToFormValues(job), ...values };
  const now = new Date().toISOString();
  const endDate =
    merged.status === "completed"
      ? merged.end_date || now.slice(0, 10)
      : merged.end_date || null;

  return {
    workspace_id: job.workspace_id,
    name: merged.name.trim(),
    client_name: merged.client_name.trim() || null,
    address: merged.address.trim() || null,
    job_number: merged.job_number.trim() || null,
    status: merged.status,
    start_date: merged.start_date || null,
    end_date: endDate,
    notes: merged.notes.trim() || null,
    created_at: job.created_at,
    updated_at: now,
  };
}
