import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";

export async function GET(
  _request: Request,
  context: { params: Promise<{ itemId: string }> },
) {
  const { itemId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const url = `${apiBaseUrl()}/api/v1/items/${itemId}/thumb?w=512`;
  const res = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    redirect: "manual",
    cache: "no-store",
  });

  if (res.status >= 300 && res.status < 400) {
    const location = res.headers.get("location");
    if (location) {
      return NextResponse.redirect(location);
    }
  }

  if (!res.ok) {
    const data = await res.json().catch(() => ({ message: "Thumbnail unavailable" }));
    return NextResponse.json(data, { status: res.status });
  }

  const body = await res.arrayBuffer();
  return new NextResponse(body, {
    status: 200,
    headers: {
      "Content-Type": res.headers.get("content-type") ?? "image/jpeg",
      "Cache-Control": "public, max-age=300",
    },
  });
}
