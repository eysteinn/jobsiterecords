import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ensureAccessToken } from "@/lib/access-token";

export async function POST(
  _request: Request,
  context: { params: Promise<{ workspaceId: string }> },
) {
  const { workspaceId } = await context.params;
  const token = await ensureAccessToken();
  const res = await fetch(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/leave`, {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
