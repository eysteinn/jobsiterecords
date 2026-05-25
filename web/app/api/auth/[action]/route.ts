import { apiBaseUrl } from "@/lib/types";
import { setAuthCookies, clearAuthCookies } from "@/lib/auth-cookies";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

async function proxyAuth(
  path: string,
  init: RequestInit,
): Promise<NextResponse> {
  const res = await fetch(`${apiBaseUrl()}${path}`, {
    ...init,
    cache: "no-store",
  });
  const data = await res.json().catch(() => ({}));
  const out = NextResponse.json(data, { status: res.status });

  if (res.ok && data.access_token && data.refresh_token) {
    const jar = await cookies();
    for (const c of setAuthCookies(data.access_token, data.refresh_token)) {
      jar.set(c);
    }
  }

  if (res.status === 401 && path.includes("/refresh")) {
    const jar = await cookies();
    for (const c of clearAuthCookies()) {
      jar.set(c);
    }
  }

  const retryAfter = res.headers.get("Retry-After");
  if (retryAfter) {
    out.headers.set("Retry-After", retryAfter);
  }
  return out;
}

export async function POST(
  request: Request,
  context: { params: Promise<{ action: string }> },
) {
  const { action } = await context.params;
  const body = await request.text();

  switch (action) {
    case "signup":
      return proxyAuth("/api/v1/auth/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    case "login":
      return proxyAuth("/api/v1/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    case "refresh":
      return proxyAuth("/api/v1/auth/refresh", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    case "logout": {
      const token = (await cookies()).get("access_token")?.value;
      const res = await fetch(`${apiBaseUrl()}/api/v1/auth/logout`, {
        method: "POST",
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        cache: "no-store",
      });
      const jar = await cookies();
      for (const c of clearAuthCookies()) {
        jar.set(c);
      }
      const data = await res.json().catch(() => ({ status: "signed_out" }));
      return NextResponse.json(data, { status: res.status });
    }
    case "magic-link":
      return proxyAuth("/api/v1/auth/magic-link", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    case "forgot-password":
      return proxyAuth("/api/v1/auth/forgot-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    case "reset-password":
      return proxyAuth("/api/v1/auth/reset-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    case "verify-magic-link":
      return proxyAuth("/api/v1/auth/magic-link/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
      });
    default:
      return NextResponse.json({ message: "Not found" }, { status: 404 });
  }
}

export async function GET() {
  const token = (await cookies()).get("access_token")?.value;
  if (!token) {
    const refresh = (await cookies()).get("refresh_token")?.value;
    if (refresh) {
      const refreshed = await fetch(`${apiBaseUrl()}/api/v1/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refresh }),
        cache: "no-store",
      });
      if (refreshed.ok) {
        const data = await refreshed.json();
        const jar = await cookies();
        if (data.access_token && data.refresh_token) {
          for (const c of setAuthCookies(data.access_token, data.refresh_token)) {
            jar.set(c);
          }
        }
        const me = await fetch(`${apiBaseUrl()}/api/v1/auth/me`, {
          headers: { Authorization: `Bearer ${data.access_token}` },
          cache: "no-store",
        });
        const meData = await me.json();
        return NextResponse.json(meData, { status: me.status });
      }
    }
    return NextResponse.json({ message: "Unauthorized" }, { status: 401 });
  }

  const res = await fetch(`${apiBaseUrl()}/api/v1/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
