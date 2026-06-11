import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";

export async function GET(
  _request: Request,
  context: { params: Promise<{ reportId: string }> },
) {
  const { reportId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const res = await fetch(`${apiBaseUrl()}/api/v1/reports/${reportId}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
