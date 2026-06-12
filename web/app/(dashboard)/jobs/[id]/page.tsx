import { Suspense } from "react";
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
    const assignmentReadOnly = bundle.read_only ?? false;
    const subscriptionReadOnly = !workspace.writable;
    const readOnly = assignmentReadOnly || subscriptionReadOnly;
    const readOnlyReason = subscriptionReadOnly
      ? "subscription"
      : assignmentReadOnly
        ? "assignment"
        : undefined;
    return (
      <Suspense>
        <JobDetailClient
          job={bundle.job}
          items={bundle.items ?? []}
          mediaFiles={bundle.media_files ?? []}
          tags={bundle.tags ?? []}
          itemTags={bundle.item_tags ?? []}
          workspaceId={workspace.id}
          readOnly={readOnly}
          readOnlyReason={readOnlyReason}
        />
      </Suspense>
    );
  } catch {
    notFound();
  }
}
