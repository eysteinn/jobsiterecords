import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";
import { apiBaseUrl } from "@/lib/types";

export async function PUT(
  request: Request,
  context: { params: Promise<{ workspaceId: string; tagId: string }> },
) {
  const { workspaceId, tagId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const body = await request.text();

  const res = await fetch(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/tags/${tagId}`, {
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
