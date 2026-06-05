import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { ACCESS_COOKIE } from "@/lib/auth-cookies";

export async function POST(
  request: Request,
  context: { params: Promise<{ itemId: string }> },
) {
  const { itemId } = await context.params;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  const body = await request.text();
  const res = await fetch(`${apiBaseUrl()}/api/v1/items/${itemId}/media-files`, {
    method: "POST",
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
