"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import styles from "./account-settings-actions.module.css";

type Props = {
  workspaceId?: string;
  workspaceName?: string;
  isOwner: boolean;
};

export function AccountSettingsActions({ workspaceId, workspaceName, isOwner }: Props) {
  const router = useRouter();
  const [leaveOpen, setLeaveOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function leaveWorkspace() {
    if (!workspaceId) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch(`/api/workspaces/${workspaceId}/leave`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not leave workspace");
        return;
      }
      setLeaveOpen(false);
      router.push("/jobs");
      router.refresh();
    } catch {
      setError("Could not leave workspace");
    } finally {
      setBusy(false);
    }
  }

  async function deleteAccount() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/me", { method: "DELETE" });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not delete account");
        return;
      }
      setDeleteOpen(false);
      router.push("/login");
      router.refresh();
    } catch {
      setError("Could not delete account");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      {workspaceId && !isOwner && (
        <section className={styles.card}>
          <h2>Leave workspace</h2>
          <p className={styles.muted}>
            Leave {workspaceName ?? "this workspace"}. You will lose access to synced jobs and
            reports. Your local-only jobs on your device are not affected.
          </p>
          <button type="button" className={styles.secondaryBtn} onClick={() => setLeaveOpen(true)}>
            Leave workspace
          </button>
        </section>
      )}

      <section className={styles.card}>
        <h2>Delete account</h2>
        <p className={styles.muted}>
          Permanently delete your Job Site Records account. Workspace records you captured will
          remain in each workspace. Owners must transfer ownership or delete the workspace first.
        </p>
        <button type="button" className={styles.dangerBtn} onClick={() => setDeleteOpen(true)}>
          Delete account
        </button>
      </section>

      {error && <p className={styles.error}>{error}</p>}

      <ConfirmDialog
        open={leaveOpen}
        title={`Leave ${workspaceName ?? "workspace"}?`}
        message="You will lose access to synced workspace jobs and reports. Your local-only jobs on your device will not be affected."
        confirmLabel="Leave workspace"
        destructive={false}
        busy={busy}
        onConfirm={() => void leaveWorkspace()}
        onCancel={() => setLeaveOpen(false)}
      />

      <ConfirmDialog
        open={deleteOpen}
        title="Delete your account?"
        message="This permanently deletes your login and ends your workspace memberships. Workspace records you captured will stay in each workspace. This cannot be undone."
        confirmLabel="Delete account"
        busy={busy}
        onConfirm={() => void deleteAccount()}
        onCancel={() => setDeleteOpen(false)}
      />
    </>
  );
}
