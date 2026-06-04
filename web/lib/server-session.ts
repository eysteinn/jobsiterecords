import type { Session } from "@/lib/types";
import { fetchSession } from "@/lib/session";
import { redirect } from "next/navigation";

export async function getServerSession(): Promise<Session | null> {
  return fetchSession();
}

export async function requireSession(): Promise<Session> {
  const session = await getServerSession();
  if (!session) {
    redirect("/login");
  }
  return session;
}
