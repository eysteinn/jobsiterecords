import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";

export async function GET(
  _request: Request,
  context: { params: Promise<{ workspaceId: string }> },
) {
  const { workspaceId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const res = await fetch(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/reports`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}

export async function POST(
  request: Request,
  context: { params: Promise<{ workspaceId: string }> },
) {
  const { workspaceId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const body = await request.json();
  const res = await fetch(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/reports`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
