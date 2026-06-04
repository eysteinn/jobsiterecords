/** Web OAuth authorize/token exchange — must be a single client ID (not comma-separated). */
export function googleClientId(): string | undefined {
  const webOnly = process.env.GOOGLE_WEB_CLIENT_ID?.trim();
  if (webOnly) return webOnly;

  const raw = process.env.GOOGLE_CLIENT_ID?.trim();
  if (!raw) return undefined;
  // API accepts multiple IDs; Google authorize URL accepts one — use the first (Web client should be listed first).
  const first = raw.split(",")[0]?.trim();
  return first || undefined;
}

export function googleClientSecret(): string | undefined {
  return process.env.GOOGLE_CLIENT_SECRET?.trim() || undefined;
}

export function appUrl(): string {
  const url =
    process.env.APP_URL?.trim() ||
    (process.env.NODE_ENV === "production"
      ? undefined
      : "http://localhost:3000");
  if (!url) {
    throw new Error("APP_URL is required for Google OAuth");
  }
  return url.replace(/\/$/, "");
}

/** Build redirect URLs from APP_URL so dev (0.0.0.0 bind) does not leak into Location headers. */
export function appRedirect(path: string): URL {
  const base = appUrl();
  return new URL(path.startsWith("/") ? path : `/${path}`, `${base}/`);
}

export function googleRedirectUri(): string {
  return `${appUrl()}/api/auth/google/callback`;
}

export function apiInternalUrl(): string {
  return (
    process.env.API_INTERNAL_URL ??
    process.env.NEXT_PUBLIC_API_URL ??
    "http://localhost:8080"
  ).replace(/\/$/, "");
}

export function oauthStateCookieOptions(maxAgeSeconds: number) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: maxAgeSeconds,
  };
}
