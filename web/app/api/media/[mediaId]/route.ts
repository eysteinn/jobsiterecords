import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ mediaId: string }> },
) {
  const { mediaId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const res = await fetch(`${apiBaseUrl()}/api/v1/media-files/${mediaId}`, {
    method: "DELETE",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    cache: "no-store",
  });
  if (res.status === 204) {
    return new NextResponse(null, { status: 204 });
  }
  const data = await res.json().catch(() => ({ message: "Delete failed" }));
  return NextResponse.json(data, { status: res.status });
}
