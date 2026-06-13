"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import type { Workspace } from "@/lib/types";
import shellStyles from "./dashboard-shell.module.css";
import jobsStyles from "./jobs-client.module.css";

type Props = {
  workspaces: Workspace[];
  activeWorkspace?: Workspace;
  variant?: "header" | "jobs";
};

export function WorkspaceSwitcher({
  workspaces,
  activeWorkspace,
  variant = "header",
}: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const styles = variant === "jobs" ? jobsStyles : shellStyles;

  if (workspaces.length === 0) {
    return <span className={styles.muted}>No workspace</span>;
  }

  async function selectWorkspace(workspaceId: string) {
    setBusy(true);
    setOpen(false);
    try {
      await fetch("/api/workspace/switch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ workspace_id: workspaceId }),
      });
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  const name = activeWorkspace?.name ?? workspaces[0].name;

  if (workspaces.length === 1) {
    if (variant === "jobs") {
      return (
        <div className={styles.workspaceBtn} style={{ cursor: "default" }}>
          <span className={styles.workspaceName}>{name}</span>
        </div>
      );
    }
    return (
      <div className={styles.workspaceSwitcher}>
        <span className={styles.workspaceLabel}>Workspace</span>
        <span className={styles.workspaceName}>
          <strong>{name}</strong>
        </span>
      </div>
    );
  }

  return (
    <div style={{ position: "relative" }}>
      {variant === "jobs" ? (
        <button
          type="button"
          className={styles.workspaceBtn}
          onClick={() => setOpen((v) => !v)}
          disabled={busy}
          aria-expanded={open}
        >
          <span className={styles.workspaceName}>{name}</span>
          <span className={styles.workspaceCaret} aria-hidden>
            ▾
          </span>
        </button>
      ) : (
        <div className={styles.workspaceSwitcher}>
          <span className={styles.workspaceLabel}>Workspace</span>
          <button
            type="button"
            className={styles.workspaceName}
            onClick={() => setOpen((v) => !v)}
            disabled={busy}
            aria-expanded={open}
          >
            <strong>{name}</strong>
            <span className={styles.workspaceCaret} aria-hidden>
              ▾
            </span>
          </button>
        </div>
      )}
      {open && (
        <div
          className={shellStyles.userDropdown}
          style={{ left: 0, right: "auto", minWidth: "14rem", top: "calc(100% + 4px)" }}
        >
          {workspaces.map((ws) => (
            <button
              key={ws.id}
              type="button"
              onClick={() => void selectWorkspace(ws.id)}
              style={{ fontWeight: ws.id === activeWorkspace?.id ? 600 : 400 }}
            >
              {ws.name}
              {ws.id === activeWorkspace?.id ? " ✓" : ""}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
