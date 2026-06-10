import { TeamPageClient } from "@/components/team-page-client";
import { getTeam } from "@/lib/api-team";
import { requireSession } from "@/lib/server-session";
import { redirect } from "next/navigation";

export default async function TeamPage() {
  const session = await requireSession();
  const workspace = session.workspaces[0];
  if (workspace?.role !== "owner") {
    redirect("/jobs");
  }
  if (!workspace) {
    redirect("/jobs");
  }

  const team = await getTeam(workspace.id);
  return <TeamPageClient workspaceId={workspace.id} initial={team} />;
}
