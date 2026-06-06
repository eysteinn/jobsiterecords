import { cookies } from "next/headers";
import { apiBaseUrl } from "./types";
import {
  clearAuthCookies,
  getAccessToken,
  getRefreshToken,
  setAuthCookies,
} from "./auth-cookies";

/** Refresh tokens and persist new cookies. Returns the new access token or null. */
export async function refreshAccessToken(): Promise<string | null> {
  const refresh = await getRefreshToken();
  if (!refresh) {
    return null;
  }

  const res = await fetch(`${apiBaseUrl()}/api/v1/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: refresh }),
    cache: "no-store",
  });

  if (!res.ok) {
    const jar = await cookies();
    for (const c of clearAuthCookies()) {
      jar.set(c);
    }
    return null;
  }

  const data = await res.json();
  if (!data.access_token || !data.refresh_token) {
    return null;
  }

  const jar = await cookies();
  for (const c of setAuthCookies(data.access_token, data.refresh_token)) {
    jar.set(c);
  }
  return data.access_token as string;
}

/** Return a valid access token, refreshing the session when the access cookie has expired. */
export async function ensureAccessToken(): Promise<string | null> {
  return (await getAccessToken()) ?? (await refreshAccessToken());
}
