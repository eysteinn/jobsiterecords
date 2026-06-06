import { ensureAccessToken, refreshAccessToken } from "./access-token";

type ProxyOptions = {
  redirect?: RequestRedirect;
  cache?: RequestCache;
};

/** Proxy a backend request with bearer auth, refreshing the session once on 401. */
export async function authenticatedProxy(
  url: string,
  options: ProxyOptions = {},
): Promise<Response> {
  const { redirect = "manual", cache = "no-store" } = options;
  let token = await ensureAccessToken();
  let res = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    redirect,
    cache,
  });

  if (res.status === 401) {
    token = await refreshAccessToken();
    if (token) {
      res = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
        redirect,
        cache,
      });
    }
  }

  return res;
}
