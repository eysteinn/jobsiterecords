import { setAuthCookies } from "@/lib/auth-cookies";
import {
  apiInternalUrl,
  appRedirect,
  googleClientId,
  googleClientSecret,
  googleRedirectUri,
  oauthStateCookieOptions,
} from "@/lib/google-oauth";
import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

const STATE_COOKIE = "oauth_state";

export async function GET(request: NextRequest) {
  const loginError = (code: string) =>
    NextResponse.redirect(appRedirect(`/login?error=${code}`));

  const state = request.nextUrl.searchParams.get("state");
  const code = request.nextUrl.searchParams.get("code");
  const storedState = request.cookies.get(STATE_COOKIE)?.value;

  const clearState = (res: NextResponse) => {
    res.cookies.set(STATE_COOKIE, "", { ...oauthStateCookieOptions(0), maxAge: 0 });
    return res;
  };

  if (!state || !storedState || state !== storedState) {
    return clearState(loginError("oauth_state"));
  }
  if (!code) {
    return clearState(loginError("oauth_failed"));
  }

  const clientId = googleClientId();
  const clientSecret = googleClientSecret();
  if (!clientId || !clientSecret) {
    return clearState(loginError("oauth_not_configured"));
  }

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: googleRedirectUri(),
      grant_type: "authorization_code",
    }),
    cache: "no-store",
  });

  if (!tokenRes.ok) {
    console.error("google token exchange failed", tokenRes.status, await tokenRes.text());
    return clearState(loginError("oauth_failed"));
  }

  const tokens = (await tokenRes.json()) as {
    id_token?: string;
  };
  if (!tokens.id_token) {
    return clearState(loginError("oauth_failed"));
  }

  const apiRes = await fetch(`${apiInternalUrl()}/api/v1/auth/oauth/google`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": request.headers.get("user-agent") ?? "web-oauth-callback",
    },
    body: JSON.stringify({ id_token: tokens.id_token }),
    cache: "no-store",
  });

  if (!apiRes.ok) {
    const errBody = await apiRes.text();
    console.error("api oauth/google failed", apiRes.status, errBody);
    return clearState(loginError("oauth_failed"));
  }

  const data = (await apiRes.json()) as {
    access_token?: string;
    refresh_token?: string;
  };
  if (!data.access_token || !data.refresh_token) {
    return clearState(loginError("oauth_failed"));
  }

  const jar = await cookies();
  for (const c of setAuthCookies(data.access_token, data.refresh_token)) {
    jar.set(c);
  }

  const next = request.nextUrl.searchParams.get("next");
  const dest = next?.startsWith("/") ? next : "/jobs";
  return clearState(NextResponse.redirect(appRedirect(dest)));
}
