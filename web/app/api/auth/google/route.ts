import {
  appRedirect,
  googleClientId,
  googleRedirectUri,
  oauthStateCookieOptions,
} from "@/lib/google-oauth";
import { NextResponse } from "next/server";

const STATE_COOKIE = "oauth_state";

export async function GET() {
  const clientId = googleClientId();
  if (!clientId) {
    return NextResponse.redirect(appRedirect("/login?error=oauth_not_configured"));
  }

  const state = crypto.randomUUID();
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: googleRedirectUri(),
    response_type: "code",
    scope: "openid email profile",
    state,
    access_type: "online",
    prompt: "select_account",
  });

  const res = NextResponse.redirect(
    `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
  );
  res.cookies.set(STATE_COOKIE, state, oauthStateCookieOptions(600));
  return res;
}
