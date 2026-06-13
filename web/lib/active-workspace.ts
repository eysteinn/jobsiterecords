import { cookies } from "next/headers";
import type { Session, Workspace } from "./types";

export const WORKSPACE_COOKIE = "jsr_workspace_id";

export function getActiveWorkspace(session: Session): Workspace | undefined {
  if (session.workspaces.length === 0) return undefined;
  return resolveActiveWorkspace(session.workspaces, undefined);
}

export async function getActiveWorkspaceFromCookies(session: Session): Promise<Workspace | undefined> {
  if (session.workspaces.length === 0) return undefined;
  const jar = await cookies();
  const preferred = jar.get(WORKSPACE_COOKIE)?.value;
  return resolveActiveWorkspace(session.workspaces, preferred);
}

export function resolveActiveWorkspace(
  workspaces: Workspace[],
  preferredId?: string,
): Workspace | undefined {
  if (workspaces.length === 0) return undefined;
  if (preferredId) {
    const match = workspaces.find((w) => w.id === preferredId);
    if (match) return match;
  }
  return workspaces[0];
}
