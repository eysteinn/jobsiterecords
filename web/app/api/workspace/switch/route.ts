import { WORKSPACE_COOKIE } from "@/lib/active-workspace";
import { getServerSession } from "@/lib/server-session";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json({ message: "Unauthorized" }, { status: 401 });
  }

  const body = (await request.json()) as { workspace_id?: string };
  const workspaceId = body.workspace_id?.trim();
  if (!workspaceId) {
    return NextResponse.json({ message: "workspace_id required" }, { status: 400 });
  }

  const allowed = session.workspaces.some((w) => w.id === workspaceId);
  if (!allowed) {
    return NextResponse.json({ message: "Workspace not found" }, { status: 403 });
  }

  const res = NextResponse.json({ status: "ok", workspace_id: workspaceId });
  res.cookies.set(WORKSPACE_COOKIE, workspaceId, {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 365 * 24 * 60 * 60,
  });
  return res;
}
