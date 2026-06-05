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
  const ifNoneMatch = request.headers.get("If-None-Match");

  const res = await fetch(`${apiBaseUrl()}/api/v1/jobs/${jobId}/cursor`, {
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(ifNoneMatch ? { "If-None-Match": ifNoneMatch } : {}),
    },
    cache: "no-store",
  });

  if (res.status === 304) {
    return new NextResponse(null, { status: 304 });
  }

  const data = await res.json();
  const headers = new Headers();
  const etag = res.headers.get("ETag");
  if (etag) headers.set("ETag", etag);
  return NextResponse.json(data, { status: res.status, headers });
}
