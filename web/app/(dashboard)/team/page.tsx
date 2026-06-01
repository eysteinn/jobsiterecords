import { EmptyState, PageShell } from "@/components/page-shell";
import { requireSession } from "@/lib/server-session";
import { redirect } from "next/navigation";

export default async function TeamPage() {
  const session = await requireSession();
  const workspace = session.workspaces[0];
  if (workspace?.role !== "owner") {
    redirect("/jobs");
  }

  return (
    <PageShell title="Team" subtitle="Invite workers to this workspace">
      <EmptyState
        title="No teammates yet"
        description="Team invites and member management ship in M5."
      />
    </PageShell>
  );
}
