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

  // The Go API returns a 302 redirect to a presigned S3 URL.
  // redirect:"manual" lets us capture that URL and forward the redirect to the browser.
  const res = await fetch(`${apiBaseUrl()}/api/v1/reports/${reportId}/download`, {
    redirect: "manual",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    cache: "no-store",
  });

  const location = res.headers.get("location");
  if ((res.status === 301 || res.status === 302) && location) {
    return NextResponse.redirect(location);
  }

  // Report not ready or error — forward the response body
  try {
    const data = await res.json();
    return NextResponse.json(data, { status: res.status });
  } catch {
    return NextResponse.json({ error: "not_ready" }, { status: 409 });
  }
}
