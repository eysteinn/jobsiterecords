import { NextResponse } from "next/server";
import { authenticatedProxy } from "@/lib/authenticated-proxy";
import { apiBaseUrl } from "@/lib/types";

export async function GET(
  request: Request,
  context: { params: Promise<{ mediaId: string }> },
) {
  const { mediaId } = await context.params;
  const inline = new URL(request.url).searchParams.get("inline") === "1";
  const url = `${apiBaseUrl()}/api/v1/media-files/${mediaId}/download${inline ? "?inline=1" : ""}`;
  const res = await authenticatedProxy(url);

  if (res.status >= 300 && res.status < 400) {
    const location = res.headers.get("location");
    if (location) {
      return NextResponse.redirect(location);
    }
  }

  if (!res.ok) {
    const data = await res.json().catch(() => ({ message: "Download unavailable" }));
    return NextResponse.json(data, { status: res.status });
  }

  const body = await res.arrayBuffer();
  return new NextResponse(body, {
    status: 200,
    headers: {
      "Content-Type": res.headers.get("content-type") ?? "application/octet-stream",
      "Cache-Control": "private, max-age=300",
    },
  });
}
