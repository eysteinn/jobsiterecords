import { getAccessToken } from "./auth-cookies";
import { apiBaseUrl, type ApiError } from "./types";

export type TeamMember = {
  user_id: string;
  email: string;
  name?: string | null;
  role: "owner" | "member";
  status: string;
  last_active_at?: string | null;
  joined_at: string;
};

export type TeamInvite = {
  id: string;
  email: string;
  role: "member";
  status: string;
  created_at: string;
  expires_at: string;
};

export type TeamSummary = {
  members: TeamMember[];
  invites: TeamInvite[];
  member_count: number;
  member_limit: number;
  pending_count: number;
};

export type InvitePreview = {
  workspace_id: string;
  workspace_name: string;
  email: string;
  role: string;
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

export function getTeam(workspaceId: string) {
  return apiFetch<TeamSummary>(`/api/v1/workspaces/${workspaceId}/team`);
}

export function createInvite(workspaceId: string, email: string) {
  return apiFetch<{ invite: TeamInvite; dev_link?: string }>(
    `/api/v1/workspaces/${workspaceId}/invites`,
    {
      method: "POST",
      body: JSON.stringify({ email }),
    },
  );
}

export function resendInvite(workspaceId: string, inviteId: string) {
  return apiFetch<{ invite: TeamInvite; dev_link?: string }>(
    `/api/v1/workspaces/${workspaceId}/invites/${inviteId}/resend`,
    { method: "POST" },
  );
}

export function revokeInvite(workspaceId: string, inviteId: string) {
  return apiFetch<{ status: string }>(
    `/api/v1/workspaces/${workspaceId}/invites/${inviteId}`,
    { method: "DELETE" },
  );
}

export function removeMember(workspaceId: string, memberUserId: string) {
  return apiFetch<{ status: string }>(
    `/api/v1/workspaces/${workspaceId}/members/${memberUserId}`,
    { method: "DELETE" },
  );
}

export function previewInvite(token: string) {
  return apiFetch<InvitePreview>(`/api/v1/invites/preview?token=${encodeURIComponent(token)}`);
}

export function acceptInvite(token: string) {
  return apiFetch<{ status: string; workspace: { id: string; name: string } }>(
    `/api/v1/invites/accept`,
    {
      method: "POST",
      body: JSON.stringify({ token }),
    },
  );
}
