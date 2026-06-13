import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ensureAccessToken } from "@/lib/access-token";

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ workspaceId: string; jobId: string; userId: string }> },
) {
  const { workspaceId, jobId, userId } = await context.params;
  const token = await ensureAccessToken();
  const res = await fetch(
    `${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/jobs/${jobId}/assignments/${userId}`,
    {
      method: "DELETE",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      cache: "no-store",
    },
  );
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
