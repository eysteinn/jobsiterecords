import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ensureAccessToken } from "@/lib/access-token";

export async function POST(
  request: Request,
  context: { params: Promise<{ workspaceId: string }> },
) {
  const { workspaceId } = await context.params;
  const body = await request.text();
  const token = await ensureAccessToken();
  const res = await fetch(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/billing/portal`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body,
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
