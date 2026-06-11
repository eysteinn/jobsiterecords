import { getAccessToken } from "./auth-cookies";
import { apiBaseUrl, type ApiError } from "./types";

export type Report = {
  id: string;
  workspace_id: string;
  job_id: string;
  created_by: string;
  title: string;
  date_from?: string | null;
  date_to?: string | null;
  include_photos: boolean;
  include_notes: boolean;
  include_voice: boolean;
  include_files: boolean;
  status: "queued" | "rendering" | "ready" | "failed";
  storage_key?: string | null;
  size_bytes?: number | null;
  page_count?: number | null;
  error_msg?: string | null;
  created_at: string;
  updated_at: string;
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

export function listReports(workspaceId: string) {
  return apiFetch<{ reports: Report[] }>(`/api/v1/workspaces/${workspaceId}/reports`);
}
