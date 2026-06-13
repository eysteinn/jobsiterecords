import { cookies, headers } from "next/headers";

export const ACCESS_COOKIE = "access_token";
export const REFRESH_COOKIE = "refresh_token";
/** Set by middleware after a silent refresh so RSC can use the new access token. */
export const REFRESHED_ACCESS_HEADER = "x-refreshed-access-token";

export async function getAccessToken(): Promise<string | undefined> {
  const h = await headers();
  const refreshed = h.get(REFRESHED_ACCESS_HEADER);
  if (refreshed) {
    return refreshed;
  }
  const jar = await cookies();
  return jar.get(ACCESS_COOKIE)?.value;
}

export async function getRefreshToken(): Promise<string | undefined> {
  const jar = await cookies();
  return jar.get(REFRESH_COOKIE)?.value;
}

export function cookieOptions(maxAgeSeconds: number) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: maxAgeSeconds,
  };
}

export function clearAuthCookies() {
  return [
    { name: ACCESS_COOKIE, value: "", ...cookieOptions(0) },
    { name: REFRESH_COOKIE, value: "", ...cookieOptions(0) },
  ];
}

export function setAuthCookies(accessToken: string, refreshToken: string) {
  return [
    { name: ACCESS_COOKIE, value: accessToken, ...cookieOptions(15 * 60) },
    {
      name: REFRESH_COOKIE,
      value: refreshToken,
      ...cookieOptions(30 * 24 * 60 * 60),
    },
  ];
}
