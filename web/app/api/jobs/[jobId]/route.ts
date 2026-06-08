import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";
import { apiBaseUrl } from "@/lib/types";

export async function GET(
  request: Request,
  context: { params: Promise<{ jobId: string }> },
) {
  const { jobId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const since = new URL(request.url).searchParams.get("since");
  const q = since ? `?since=${encodeURIComponent(since)}` : "";

  const res = await fetch(`${apiBaseUrl()}/api/v1/jobs/${jobId}${q}`, {
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}

export async function PUT(
  request: Request,
  context: { params: Promise<{ jobId: string }> },
) {
  const { jobId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const body = await request.text();
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
