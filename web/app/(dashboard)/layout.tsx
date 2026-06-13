import { DashboardShell } from "@/components/dashboard-shell";
import { getActiveWorkspaceFromCookies } from "@/lib/active-workspace";
import { requireSession } from "@/lib/server-session";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await requireSession();
  const activeWorkspace = await getActiveWorkspaceFromCookies(session);
  return (
    <DashboardShell session={session} activeWorkspace={activeWorkspace}>
      {children}
    </DashboardShell>
  );
}
