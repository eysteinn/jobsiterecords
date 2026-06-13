import { getAccessToken } from "./auth-cookies";
import { apiBaseUrl, type ApiError } from "./types";

export type JobAssignment = {
  job_id: string;
  user_id: string;
};

export type AssignmentsResponse = {
  assignments?: JobAssignment[];
  assigned_job_ids?: string[];
};

async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await getAccessToken();
  const res = await fetch(`${apiBaseUrl()}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
    cache: "no-store",
  });
  const data = await res.json();
  if (!res.ok) {
    const err = data as ApiError;
    throw new Error(err.message || "Request failed");
  }
  return data as T;
}

export function getAssignments(workspaceId: string) {
  return apiFetch<AssignmentsResponse>(`/api/v1/workspaces/${workspaceId}/assignments`);
}

export function assignMember(workspaceId: string, jobId: string, userId: string) {
  return apiFetch<{ status: string }>(
    `/api/v1/workspaces/${workspaceId}/jobs/${jobId}/assignments`,
    {
      method: "POST",
      body: JSON.stringify({ user_id: userId }),
    },
  );
}

export function unassignMember(workspaceId: string, jobId: string, userId: string) {
  return apiFetch<{ status: string }>(
    `/api/v1/workspaces/${workspaceId}/jobs/${jobId}/assignments/${userId}`,
    { method: "DELETE" },
  );
}
