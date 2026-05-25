import { JobDetailClient } from "@/components/job-detail-client";
import { getJob } from "@/lib/api-jobs";
import { requireSession } from "@/lib/server-session";
import { notFound } from "next/navigation";

export default async function JobDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const session = await requireSession();
  const workspace = session.workspaces[0];
  if (!workspace) notFound();

  try {
    const bundle = await getJob(id);
    return (
      <JobDetailClient
        job={bundle.job}
        items={bundle.items ?? []}
        workspaceId={workspace.id}
      />
    );
  } catch {
    notFound();
  }
}
