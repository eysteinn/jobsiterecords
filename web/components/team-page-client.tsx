"use client";

import { FormEvent, useMemo, useState } from "react";
import Link from "next/link";
import type { TeamInvite, TeamMember, TeamSummary } from "@/lib/api-team";
import { PageShell } from "@/components/page-shell";
import styles from "./team-client.module.css";

type Props = {
  workspaceId: string;
  initial: TeamSummary;
  workspaceWritable?: boolean;
};

function normalizeTeam(data: TeamSummary): TeamSummary {
  return {
    members: data.members ?? [],
    invites: data.invites ?? [],
    member_count: data.member_count ?? data.members?.length ?? 0,
    member_limit: data.member_limit ?? 1,
    pending_count: data.pending_count ?? data.invites?.length ?? 0,
  };
}

function initials(email: string, name?: string | null): string {
  if (name?.trim()) {
    const parts = name.trim().split(/\s+/).filter(Boolean);
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    if (parts[0]) return parts[0].slice(0, 2).toUpperCase();
  }
  const local = (email.split("@")[0] ?? "").trim();
  const parts = local.split(/[._-]/).filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return local.slice(0, 2).toUpperCase();
}

function formatLastActive(value?: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

type Row =
  | { kind: "member"; member: TeamMember }
  | { kind: "invite"; invite: TeamInvite };

export function TeamPageClient({ workspaceId, initial, workspaceWritable = true }: Props) {
  const [team, setTeam] = useState(() => normalizeTeam(initial));
  const [inviteEmail, setInviteEmail] = useState("");
  const [showInviteRow, setShowInviteRow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [devLink, setDevLink] = useState<string | null>(null);
  const [openMenu, setOpenMenu] = useState<string | null>(null);

  const atLimit = team.member_count + team.pending_count >= team.member_limit;

  const rows = useMemo<Row[]>(() => {
    const inviteRows: Row[] = team.invites.map((invite) => ({ kind: "invite", invite }));
    const memberRows: Row[] = team.members.map((member) => ({ kind: "member", member }));
    return [...inviteRows, ...memberRows];
  }, [team]);

  async function refreshTeam() {
    const res = await fetch(`/api/workspaces/${workspaceId}/team`, { cache: "no-store" });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not refresh team");
    setTeam(normalizeTeam(data));
  }

  async function onInvite(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setDevLink(null);
    try {
      const res = await fetch(`/api/workspaces/${workspaceId}/invites`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: inviteEmail }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not send invite");
        return;
      }
      setInviteEmail("");
      setShowInviteRow(false);
      if (data.dev_link) setDevLink(data.dev_link);
      await refreshTeam();
    } catch {
      setError("Could not send invite");
    } finally {
      setBusy(false);
    }
  }

  async function resendInvite(inviteId: string) {
    setBusy(true);
    setError(null);
    setDevLink(null);
    setOpenMenu(null);
    try {
      const res = await fetch(`/api/workspaces/${workspaceId}/invites/${inviteId}/resend`, {
        method: "POST",
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not resend invite");
        return;
      }
      if (data.dev_link) setDevLink(data.dev_link);
      await refreshTeam();
    } catch {
      setError("Could not resend invite");
    } finally {
      setBusy(false);
    }
  }

  async function cancelInvite(inviteId: string) {
    if (!confirm("Cancel this invite?")) return;
    setBusy(true);
    setError(null);
    setOpenMenu(null);
    try {
      const res = await fetch(`/api/workspaces/${workspaceId}/invites/${inviteId}`, {
        method: "DELETE",
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not cancel invite");
        return;
      }
      await refreshTeam();
    } catch {
      setError("Could not cancel invite");
    } finally {
      setBusy(false);
    }
  }

  async function removeMember(memberUserId: string, label: string) {
    if (!confirm(`Remove ${label} from this workspace?`)) return;
    setBusy(true);
    setError(null);
    setOpenMenu(null);
    try {
      const res = await fetch(`/api/workspaces/${workspaceId}/members/${memberUserId}`, {
        method: "DELETE",
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not remove member");
        return;
      }
      await refreshTeam();
    } catch {
      setError("Could not remove member");
    } finally {
      setBusy(false);
    }
  }

  return (
    <PageShell
      title="Team"
      subtitle="Invite workers to this workspace"
      action={
        <button
          type="button"
          className={styles.primary}
          disabled={!workspaceWritable || atLimit || showInviteRow}
          onClick={() => setShowInviteRow(true)}
        >
          + Invite worker
        </button>
      }
    >
      <p className={styles.limitNote}>
        Members: {team.member_count} / {team.member_limit}
        {team.pending_count > 0 ? ` · ${team.pending_count} pending` : ""}
        {!workspaceWritable && (
          <>
            {" "}
            — Workspace is read-only. <Link href="/settings">Upgrade</Link> to invite team members.
          </>
        )}
        {atLimit && (
          <>
            {" "}
            — At limit. <Link href="/settings">Manage subscription</Link> to add more.
          </>
        )}
      </p>

      {error && <p className={styles.error}>{error}</p>}
      {devLink && (
        <p className={styles.devLink}>
          Dev invite link: <a href={devLink}>{devLink}</a>
        </p>
      )}

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Person</th>
              <th>Role</th>
              <th>Last active</th>
              <th aria-label="Actions" />
            </tr>
          </thead>
          <tbody>
            {showInviteRow && (
              <tr className={styles.inviteRow}>
                <td colSpan={4}>
                  <form className={styles.inviteForm} onSubmit={(e) => void onInvite(e)}>
                    <input
                      type="email"
                      required
                      placeholder="worker@example.com"
                      value={inviteEmail}
                      onChange={(e) => setInviteEmail(e.target.value)}
                      disabled={busy || atLimit}
                      autoFocus
                    />
                    <button type="submit" className={styles.primary} disabled={busy || atLimit}>
                      Send invite
                    </button>
                    <button
                      type="button"
                      className={styles.secondary}
                      onClick={() => {
                        setShowInviteRow(false);
                        setInviteEmail("");
                      }}
                      disabled={busy}
                    >
                      Cancel
                    </button>
                  </form>
                </td>
              </tr>
            )}

            {rows.length === 0 && !showInviteRow && (
              <tr>
                <td colSpan={4} style={{ color: "var(--muted)", textAlign: "center" }}>
                  No teammates yet. Invite a worker to get started.
                </td>
              </tr>
            )}

            {rows.map((row) => {
              if (row.kind === "invite") {
                const invite = row.invite;
                return (
                  <tr key={`invite-${invite.id}`} className={styles.inviteRow}>
                    <td>
                      <div className={styles.person}>
                        <span className={styles.avatar}>{initials(invite.email)}</span>
                        <div className={styles.personText}>
                          <strong>{invite.email}</strong>
                          <span>Invite pending</span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className={`${styles.pill} ${styles.pillPending}`}>Pending</span>
                    </td>
                    <td>—</td>
                    <td>
                      <div className={styles.actions}>
                        <button
                          type="button"
                          className={styles.secondary}
                          disabled={busy}
                          onClick={() => void resendInvite(invite.id)}
                        >
                          Resend
                        </button>
                        <button
                          type="button"
                          className={styles.secondary}
                          disabled={busy}
                          onClick={() => void cancelInvite(invite.id)}
                        >
                          Cancel
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              }

              const member = row.member;
              const label = member.name?.trim() || member.email;
              const menuId = `member-${member.user_id}`;
              return (
                <tr key={member.user_id}>
                  <td>
                    <div className={styles.person}>
                      <span className={styles.avatar}>{initials(member.email, member.name)}</span>
                      <div className={styles.personText}>
                        <strong>{label}</strong>
                        {member.name?.trim() ? <span>{member.email}</span> : null}
                      </div>
                    </div>
                  </td>
                  <td>
                    <span
                      className={`${styles.pill} ${member.role === "owner" ? styles.pillOwner : ""}`}
                    >
                      {member.role}
                    </span>
                  </td>
                  <td>{formatLastActive(member.last_active_at)}</td>
                  <td>
                    {member.role !== "owner" && (
                      <div className={styles.menuWrap}>
                        <button
                          type="button"
                          className={styles.menuBtn}
                          aria-label={`Actions for ${label}`}
                          onClick={() => setOpenMenu((v) => (v === menuId ? null : menuId))}
                        >
                          ⋯
                        </button>
                        {openMenu === menuId && (
                          <div className={styles.menu}>
                            <button
                              type="button"
                              className={styles.danger}
                              disabled={busy}
                              onClick={() => void removeMember(member.user_id, label)}
                            >
                              Remove
                            </button>
                          </div>
                        )}
                      </div>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </PageShell>
  );
}
