import { NextResponse } from "next/server";
import { authenticatedProxy } from "@/lib/authenticated-proxy";
import { apiBaseUrl } from "@/lib/types";

export async function GET(
  request: Request,
  context: { params: Promise<{ itemId: string }> },
) {
  const { itemId } = await context.params;
  const w = new URL(request.url).searchParams.get("w") ?? "512";
  // v= is a cache-buster from the client (display media updated_at); forward for consistency.
  const v = new URL(request.url).searchParams.get("v");
  const qs = new URLSearchParams({ w });
  if (v) qs.set("v", v);
  const url = `${apiBaseUrl()}/api/v1/items/${itemId}/thumb?${qs.toString()}`;
  const res = await authenticatedProxy(url);

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
      "Cache-Control": "private, max-age=60",
    },
  });
}
