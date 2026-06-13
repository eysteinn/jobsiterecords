"use client";

import { useEffect, useRef, useState } from "react";
import type { TeamMember } from "@/lib/api-team";
import styles from "./job-assignees.module.css";

type Props = {
  workspaceId: string;
  jobId: string;
  members: TeamMember[];
  assigneeIds: string[];
  onAssigneeIdsChange: (ids: string[]) => void;
};

function memberLabel(member: TeamMember): string {
  return member.name?.trim() || member.email;
}

export function JobAssignees({
  workspaceId,
  jobId,
  members,
  assigneeIds,
  onAssigneeIdsChange,
}: Props) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onPointerDown(event: PointerEvent) {
      if (wrapRef.current && !wrapRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [open]);

  async function toggleMember(userId: string, assigned: boolean) {
    setBusy(true);
    setError(null);
    const prev = assigneeIds;
    const next = assigned
      ? prev.filter((id) => id !== userId)
      : [...prev, userId];
    onAssigneeIdsChange(next);
    try {
      const path = assigned
        ? `/api/workspaces/${workspaceId}/jobs/${jobId}/assignments/${userId}`
        : `/api/workspaces/${workspaceId}/jobs/${jobId}/assignments`;
      const res = await fetch(path, {
        method: assigned ? "DELETE" : "POST",
        headers: assigned ? undefined : { "Content-Type": "application/json" },
        body: assigned ? undefined : JSON.stringify({ user_id: userId }),
      });
      const data = await res.json();
      if (!res.ok) {
        onAssigneeIdsChange(prev);
        setError(data.message || "Could not update assignment");
      }
    } catch {
      onAssigneeIdsChange(prev);
      setError("Could not update assignment");
    } finally {
      setBusy(false);
    }
  }

  if (members.length === 0) {
    return (
      <p className={styles.muted}>No team members to assign. Invite workers from the Team page.</p>
    );
  }

  const assigneeSet = new Set(assigneeIds);
  const assigneeNames = members
    .filter((member) => assigneeSet.has(member.user_id))
    .map(memberLabel);

  return (
    <div className={styles.wrap} ref={wrapRef}>
      <div className={styles.row}>
        <span className={styles.label}>Assigned to</span>
        <button
          type="button"
          className={styles.trigger}
          onClick={() => setOpen((v) => !v)}
          disabled={busy}
          aria-expanded={open}
        >
          {assigneeNames.length > 0 ? assigneeNames.join(", ") : "No one assigned"}
          <span aria-hidden> ▾</span>
        </button>
      </div>
      {error && <p className={styles.error}>{error}</p>}
      {open && (
        <div className={styles.menu} role="listbox" aria-label="Assign team members">
          {members.map((member) => {
            const checked = assigneeSet.has(member.user_id);
            return (
              <label key={member.user_id} className={styles.option}>
                <input
                  type="checkbox"
                  checked={checked}
                  disabled={busy}
                  onChange={() => void toggleMember(member.user_id, checked)}
                />
                <span>
                  <strong>{memberLabel(member)}</strong>
                  {member.name?.trim() ? (
                    <span className={styles.optionEmail}>{member.email}</span>
                  ) : null}
                </span>
              </label>
            );
          })}
        </div>
      )}
    </div>
  );
}

export function JobAssigneeNames({
  assignees,
}: {
  assignees: Pick<TeamMember, "user_id" | "email" | "name">[];
}) {
  if (assignees.length === 0) return null;
  const names = assignees.map((member) => member.name?.trim() || member.email);
  return <p className={styles.names}>Assigned to {names.join(", ")}</p>;
}
