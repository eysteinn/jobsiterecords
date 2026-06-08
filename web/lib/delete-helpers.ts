import type { Item, Job } from "@/lib/api-jobs";

export function itemKindLabel(kind: Item["kind"], plural = false): string {
  if (plural) return "photos/notes/files";
  return (
    {
      photo: "photo",
      voice: "voice note",
      note: "note",
      file: "file",
    } as const
  )[kind];
}

export function singleItemDeleteCopy(item: Item) {
  return {
    title: "Delete this item?",
    message: `This will remove the ${itemKindLabel(item.kind)} from this job.`,
    confirmLabel: "Delete",
  };
}

export function bulkItemDeleteCopy(count: number) {
  return {
    title: `Delete ${count} selected item${count === 1 ? "" : "s"}?`,
    message: "This will remove the selected photos/notes/files from this job.",
    confirmLabel: count === 1 ? "Delete item" : `Delete ${count} items`,
  };
}

export function jobDeleteCopy(jobName: string) {
  return {
    title: `Delete job “${jobName}”?`,
    message: "This will delete all photos, notes, files, and voice notes in this job.",
    confirmLabel: "Delete job",
  };
}

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
