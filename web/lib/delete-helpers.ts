import type { Item, Job } from "@/lib/api-jobs";

export function filterActiveItems<T extends { deleted_at?: string | null }>(items: T[]): T[] {
  return items.filter((item) => !item.deleted_at);
}

export function filterActiveJobs<T extends { deleted_at?: string | null }>(jobs: T[]): T[] {
  return jobs.filter((job) => !job.deleted_at);
}

export function buildItemDeletePayload(item: Item) {
  const now = new Date().toISOString();
  return {
    kind: item.kind,
    body: item.body,
    caption: item.caption,
    captured_at: item.captured_at,
    created_at: item.created_at,
    updated_at: now,
    deleted_at: now,
  };
}

export function buildItemRestorePayload(item: Item) {
  const now = new Date().toISOString();
  return {
    kind: item.kind,
    body: item.body,
    caption: item.caption,
    captured_at: item.captured_at,
    created_at: item.created_at,
    updated_at: now,
  };
}

export function buildJobDeletePayload(job: Job) {
  const now = new Date().toISOString();
  return {
    workspace_id: job.workspace_id,
    name: job.name,
    client_name: job.client_name,
    address: job.address,
    job_number: job.job_number,
    status: job.status,
    start_date: job.start_date,
    end_date: job.end_date,
    notes: job.notes,
    cover_item_id: job.cover_item_id,
    created_at: job.created_at,
    updated_at: now,
    deleted_at: now,
  };
}
