export const dynamic = "force-dynamic";

import { Suspense } from "react";
import { ReportsClient } from "@/components/reports-client";
import { listReports } from "@/lib/api-reports";
import { listJobs } from "@/lib/api-jobs";
import { getActiveWorkspaceFromCookies } from "@/lib/active-workspace";
import { requireSession } from "@/lib/server-session";

export default async function ReportsPage() {
  const session = await requireSession();
  const workspace = await getActiveWorkspaceFromCookies(session);
  if (!workspace) {
    return <p>No workspace found for this account.</p>;
  }
  const [{ reports }, { jobs }] = await Promise.all([
    listReports(workspace.id),
    listJobs(workspace.id),
  ]);
  return (
    <Suspense>
      <ReportsClient
        workspaceId={workspace.id}
        initialReports={reports}
        jobs={jobs}
      />
    </Suspense>
  );
}
