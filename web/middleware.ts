import { clearAuthCookies, REFRESHED_ACCESS_HEADER } from "@/lib/auth-cookies";
import { appRedirect } from "@/lib/google-oauth";
import { isAccessTokenExpiredEdge } from "@/lib/jwt";
import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const publicPaths = [
  "/login",
  "/signup",
  "/forgot-password",
  "/reset-password",
  "/auth/verify",
];

function apiBaseUrl() {
  return (
    process.env.API_INTERNAL_URL ??
    process.env.NEXT_PUBLIC_API_URL ??
    "http://localhost:8080"
  );
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (
    pathname.startsWith("/api/") ||
    pathname.startsWith("/_next/") ||
    pathname === "/favicon.ico"
  ) {
    return NextResponse.next();
  }

  const isPublic = publicPaths.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );

  let access = request.cookies.get("access_token")?.value;
  const refresh = request.cookies.get("refresh_token")?.value;
  let response = NextResponse.next();

  const accessMissingOrExpired = !access || isAccessTokenExpiredEdge(access);
  if (refresh && accessMissingOrExpired) {
    try {
      const refreshed = await fetch(`${apiBaseUrl()}/api/v1/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refresh }),
        cache: "no-store",
      });
      if (refreshed.ok) {
        const data = await refreshed.json();
        if (data.access_token && data.refresh_token) {
          access = data.access_token;
          const requestHeaders = new Headers(request.headers);
          requestHeaders.set(REFRESHED_ACCESS_HEADER, data.access_token);
          response = NextResponse.next({
            request: { headers: requestHeaders },
          });
          response.cookies.set("access_token", data.access_token, {
            httpOnly: true,
            sameSite: "lax",
            path: "/",
            maxAge: 15 * 60,
          });
          response.cookies.set("refresh_token", data.refresh_token, {
            httpOnly: true,
            sameSite: "lax",
            path: "/",
            maxAge: 30 * 24 * 60 * 60,
          });
        }
      } else {
        access = undefined;
        response = NextResponse.next();
        for (const c of clearAuthCookies()) {
          response.cookies.set(c.name, c.value, {
            httpOnly: c.httpOnly,
            sameSite: c.sameSite,
            path: c.path,
            maxAge: c.maxAge,
            secure: c.secure,
          });
        }
      }
    } catch {
      access = undefined;
      response = NextResponse.next();
      for (const c of clearAuthCookies()) {
        response.cookies.set(c.name, c.value, {
          httpOnly: c.httpOnly,
          sameSite: c.sameSite,
          path: c.path,
          maxAge: c.maxAge,
          secure: c.secure,
        });
      }
    }
  }

  const authed = Boolean(access) && !isAccessTokenExpiredEdge(access);

  if (!isPublic && !authed) {
    const login = appRedirect("/login");
    login.searchParams.set("next", pathname);
    return NextResponse.redirect(login);
  }

  if (isPublic && authed && pathname !== "/auth/verify") {
    return NextResponse.redirect(appRedirect("/jobs"));
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image).*)"],
};
