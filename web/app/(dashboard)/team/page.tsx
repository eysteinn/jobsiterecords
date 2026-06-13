import { EmptyState, PageShell } from "@/components/page-shell";
import { TeamPageClient } from "@/components/team-page-client";
import { getTeam } from "@/lib/api-team";
import { getActiveWorkspaceFromCookies } from "@/lib/active-workspace";
import { requireSession } from "@/lib/server-session";
import { redirect } from "next/navigation";

export default async function TeamPage() {
  const session = await requireSession();
  const workspace = await getActiveWorkspaceFromCookies(session);
  if (!workspace) {
    redirect("/jobs");
  }
  if (workspace.role !== "owner") {
    redirect("/jobs");
  }

  try {
    const team = await getTeam(workspace.id);
    return (
      <TeamPageClient
        workspaceId={workspace.id}
        workspaceName={workspace.name}
        initial={team}
        workspaceWritable={workspace.writable}
      />
    );
  } catch {
    return (
      <PageShell title="Team" subtitle="Invite workers to this workspace">
        <EmptyState
          title="Could not load team"
          description="Team management may not be available yet. Ensure the API is updated and migrations have run, then try again."
        />
      </PageShell>
    );
  }
}
