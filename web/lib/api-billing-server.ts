import { getAccessToken } from "@/lib/auth-cookies";
import type { WorkspaceBilling } from "@/lib/api-billing";
import { apiBaseUrl, type ApiError } from "@/lib/types";

export async function getWorkspaceBillingServer(workspaceId: string): Promise<WorkspaceBilling> {
  const token = await getAccessToken();
  const res = await fetch(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/billing`, {
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    cache: "no-store",
  });
  const data = await res.json();
  if (!res.ok) {
    const err = data as ApiError;
    throw new Error(err.message || "Could not load billing");
  }
  return data as WorkspaceBilling;
}
