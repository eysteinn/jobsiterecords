import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";

async function proxyPut(workspaceId: string, jobId: string, body: string) {
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const res = await fetch(`${apiBaseUrl()}/api/v1/jobs/${jobId}`, {
    method: "PUT",
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

export async function PUT(
  request: Request,
  context: { params: Promise<{ workspaceId: string; jobId: string }> },
) {
  const { workspaceId, jobId } = await context.params;
  const body = await request.text();
  void workspaceId;
  return proxyPut(workspaceId, jobId, body);
}
