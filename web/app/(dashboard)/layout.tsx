import { DashboardShell } from "@/components/dashboard-shell";
import { requireSession } from "@/lib/server-session";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await requireSession();
  return <DashboardShell session={session}>{children}</DashboardShell>;
}
