/** True when the JWT access token is missing, malformed, or past expiry. */
export function isAccessTokenExpired(token: string): boolean {
  try {
    const part = token.split(".")[1];
    if (!part) {
      return true;
    }
    const payload = JSON.parse(
      Buffer.from(part, "base64url").toString("utf8"),
    ) as { exp?: number };
    if (typeof payload.exp !== "number") {
      return true;
    }
    // Small skew so we refresh slightly before the API rejects the token.
    return payload.exp * 1000 <= Date.now() + 30_000;
  } catch {
    return true;
  }
}

/** Edge-safe variant for middleware (no Node Buffer). */
export function isAccessTokenExpiredEdge(token: string): boolean {
  try {
    const part = token.split(".")[1];
    if (!part) {
      return true;
    }
    const base64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(base64)) as { exp?: number };
    if (typeof payload.exp !== "number") {
      return true;
    }
    return payload.exp * 1000 <= Date.now() + 30_000;
  } catch {
    return true;
  }
}
