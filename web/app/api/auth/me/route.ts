import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { apiBaseUrl } from "@/lib/types";
import { clearAuthCookies } from "@/lib/auth-cookies";
import { ensureAccessToken } from "@/lib/access-token";

export async function DELETE() {
  const token = await ensureAccessToken();
  const res = await fetch(`${apiBaseUrl()}/api/v1/auth/me`, {
    method: "DELETE",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    cache: "no-store",
  });
  const data = await res.json();
  const out = NextResponse.json(data, { status: res.status });
  if (res.ok) {
    const jar = await cookies();
    for (const c of clearAuthCookies()) {
      jar.set(c);
    }
  }
  return out;
}
