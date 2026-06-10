import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";

export async function GET(request: Request) {
  const token = new URL(request.url).searchParams.get("token");
  if (!token) {
    return NextResponse.json(
      { error: "invalid_token", message: "Missing invite token" },
      { status: 400 },
    );
  }
  const res = await fetch(
    `${apiBaseUrl()}/api/v1/invites/preview?token=${encodeURIComponent(token)}`,
    { cache: "no-store" },
  );
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
