import { apiBaseUrl, type ApiError, type Session } from "./types";
import {
  ACCESS_COOKIE,
  REFRESH_COOKIE,
  clearAuthCookies,
  cookieOptions,
  getAccessToken,
  getRefreshToken,
} from "./auth-cookies";
import { cookies } from "next/headers";

async function parseJson<T>(res: Response): Promise<T> {
  const data = (await res.json()) as T & ApiError;
  if (!res.ok) {
    throw new Error(data.message || "Request failed");
  }
  return data;
}

export async function fetchSession(): Promise<Session | null> {
  const token = await getAccessToken();
  if (!token) {
    return tryRefreshSession();
  }

  const res = await fetch(`${apiBaseUrl()}/api/v1/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });

  if (res.status === 401) {
    return tryRefreshSession();
  }
  if (!res.ok) {
    return null;
  }

  const data = await res.json();
  return { user: data.user, workspaces: data.workspaces ?? [] };
}

async function tryRefreshSession(): Promise<Session | null> {
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
  const jar = await cookies();
  jar.set({
    name: ACCESS_COOKIE,
    value: data.access_token,
    ...cookieOptions(15 * 60),
  });
  // Refresh token rotates — API returns it in Set-Cookie on direct calls;
  // our BFF refresh route will set both cookies.

  const meRes = await fetch(`${apiBaseUrl()}/api/v1/auth/me`, {
    headers: { Authorization: `Bearer ${data.access_token}` },
    cache: "no-store",
  });
  if (!meRes.ok) {
    return null;
  }
  const me = await meRes.json();
  return { user: me.user, workspaces: me.workspaces ?? [] };
}

export { parseJson, apiBaseUrl };
