import { getAccessToken } from "./auth-cookies";
import { apiBaseUrl, type ApiError } from "./types";

export type Job = {
  id: string;
  workspace_id: string;
  name: string;
  client_name?: string | null;
  address?: string | null;
  job_number?: string | null;
  status: "planning" | "in_progress" | "completed";
  cover_item_id?: string | null;
  start_date?: string | null;
  end_date?: string | null;
  notes?: string | null;
  created_at: string;
  updated_at: string;
  last_activity_at: string;
};

export type MediaFile = {
  id: string;
  workspace_id: string;
  item_id: string;
  role:
    | "primary_photo"
    | "annotated_render"
    | "annotation_overlay"
    | "voice_note"
    | "attachment"
    | "file";
  mime_type: string;
  width?: number | null;
  height?: number | null;
  duration_ms?: number | null;
  size_bytes: number;
  original_filename?: string | null;
  status: "pending" | "uploaded" | "failed";
  created_at: string;
  updated_at: string;
};

export type Item = {
  id: string;
  workspace_id: string;
  job_id: string;
  kind: "photo" | "voice" | "note" | "file";
  caption?: string | null;
  body?: string | null;
  captured_at: string;
  created_at: string;
  updated_at: string;
};

export type Tag = {
  id: string;
  workspace_id: string;
  name: string;
};

export type ItemTag = {
  item_id: string;
  tag_id: string;
};

export type JobBundle = {
  job: Job;
  items: Item[];
  media_files: MediaFile[];
  tags?: Tag[];
  item_tags?: ItemTag[];
  read_only?: boolean;
};

async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await getAccessToken();
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const res = await fetch(`${apiBaseUrl()}${path}`, {
    ...init,
    headers,
    cache: "no-store",
  });
  const data = await res.json();
  if (!res.ok) {
    const err = data as ApiError;
    throw new Error(err.message || "Request failed");
  }
  return data as T;
}

export function listJobs(workspaceId: string) {
  return apiFetch<{ jobs: Job[] }>(`/api/v1/workspaces/${workspaceId}/jobs`);
}

export function getJob(jobId: string, since?: string) {
  const q = since ? `?since=${encodeURIComponent(since)}` : "";
  return apiFetch<JobBundle>(`/api/v1/jobs/${jobId}${q}`);
}

export function upsertJob(jobId: string, body: Partial<Job> & { workspace_id: string; updated_at: string }) {
  return apiFetch<Job>(`/api/v1/jobs/${jobId}`, {
    method: "PUT",
    body: JSON.stringify(body),
  });
}

export function upsertItem(jobId: string, itemId: string, body: Partial<Item> & { kind: string; captured_at: string; updated_at: string }) {
  return apiFetch<Item>(`/api/v1/jobs/${jobId}/items/${itemId}`, {
    method: "PUT",
    body: JSON.stringify(body),
  });
}
