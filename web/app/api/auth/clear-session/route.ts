import { clearAuthCookies } from "@/lib/auth-cookies";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

/** Clear auth cookies and redirect (used when RSC cannot modify cookies). */
export async function GET(request: Request) {
  const jar = await cookies();
  for (const c of clearAuthCookies()) {
    jar.set(c);
  }

  const next = new URL(request.url).searchParams.get("next") ?? "/login";
  const target = next.startsWith("/") ? next : "/login";
  return NextResponse.redirect(new URL(target, request.url));
}
