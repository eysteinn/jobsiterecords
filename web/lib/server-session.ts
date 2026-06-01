import type { Session } from "@/lib/types";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

function apiBaseUrl() {
  return (
    process.env.API_INTERNAL_URL ??
    process.env.NEXT_PUBLIC_API_URL ??
    "http://localhost:8080"
  );
}

export async function getServerSession(): Promise<Session | null> {
  const jar = await cookies();
  const token = jar.get("access_token")?.value;
  if (!token) {
    return null;
  }

  const res = await fetch(`${apiBaseUrl()}/api/v1/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });
  if (!res.ok) {
    return null;
  }
  const data = await res.json();
  return { user: data.user, workspaces: data.workspaces ?? [] };
}

export async function requireSession(): Promise<Session> {
  const session = await getServerSession();
  if (!session) {
    redirect("/login");
  }
  return session;
}
