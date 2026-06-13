import { Suspense } from "react";
import { JobDetailClient } from "@/components/job-detail-client";
import { getAssignments } from "@/lib/api-assignments";
import { getJob } from "@/lib/api-jobs";
import { getTeam } from "@/lib/api-team";
import { getActiveWorkspaceFromCookies } from "@/lib/active-workspace";
import { requireSession } from "@/lib/server-session";
import { notFound } from "next/navigation";

export default async function JobDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const session = await requireSession();
  const workspace = await getActiveWorkspaceFromCookies(session);
  if (!workspace) notFound();

  try {
    const bundle = await getJob(id);
    if (bundle.job.workspace_id !== workspace.id) notFound();

    const assignmentReadOnly = bundle.read_only ?? false;
    const subscriptionReadOnly = !workspace.writable;
    const readOnly = assignmentReadOnly || subscriptionReadOnly;
    const readOnlyReason = subscriptionReadOnly
      ? "subscription"
      : assignmentReadOnly
        ? "assignment"
        : undefined;

    const isOwner = workspace.role === "owner";
    let assignableMembers: Awaited<ReturnType<typeof getTeam>>["members"] = [];
    let assigneeIds: string[] = [];

    if (isOwner) {
      const [team, assignments] = await Promise.all([
        getTeam(workspace.id),
        getAssignments(workspace.id),
      ]);
      assignableMembers = team.members.filter((member) => member.role === "member");
      assigneeIds = (assignments.assignments ?? [])
        .filter((assignment) => assignment.job_id === id)
        .map((assignment) => assignment.user_id);
    }

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
          isOwner={isOwner}
          assignableMembers={assignableMembers}
          initialAssigneeIds={assigneeIds}
          assignees={assignableMembers.filter((member) => assigneeIds.includes(member.user_id))}
        />
      </Suspense>
    );
  } catch {
    notFound();
  }
}
