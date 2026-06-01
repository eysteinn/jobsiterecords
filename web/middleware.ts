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

  if (!access && refresh) {
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
      }
    } catch {
      // fall through to auth redirect
    }
  }

  const authed = Boolean(access || refresh);

  if (!isPublic && !authed) {
    const login = new URL("/login", request.url);
    login.searchParams.set("next", pathname);
    return NextResponse.redirect(login);
  }

  if (isPublic && authed && pathname !== "/auth/verify") {
    return NextResponse.redirect(new URL("/jobs", request.url));
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image).*)"],
};
