export const dynamic = "force-dynamic";

import { Suspense } from "react";
import { JobsClient } from "@/components/jobs-client";
import { listJobs } from "@/lib/api-jobs";
import { requireSession } from "@/lib/server-session";

export default async function JobsPage() {
  const session = await requireSession();
  const workspace = session.workspaces[0];
  if (!workspace) {
    return <p>No workspace found for this account.</p>;
  }
  const { jobs } = await listJobs(workspace.id);
  return (
    <Suspense>
      <JobsClient
        workspaceId={workspace.id}
        workspaceName={workspace.name}
        userEmail={session.user.email}
        jobs={jobs}
        workspaceWritable={workspace.writable}
      />
    </Suspense>
  );
}
