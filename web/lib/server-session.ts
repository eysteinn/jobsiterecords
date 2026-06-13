import { getAccessToken, getRefreshToken } from "@/lib/auth-cookies";
import type { Session } from "@/lib/types";
import { fetchSession } from "@/lib/session";
import { redirect } from "next/navigation";

export async function getServerSession(): Promise<Session | null> {
  return fetchSession();
}

export async function requireSession(): Promise<Session> {
  const session = await getServerSession();
  if (!session) {
    const access = await getAccessToken();
    const refresh = await getRefreshToken();
    if (access || refresh) {
      redirect("/api/auth/clear-session?next=/login");
    }
    redirect("/login");
  }
  return session;
}
