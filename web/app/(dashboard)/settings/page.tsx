import { DashboardSyncSettings } from "@/components/dashboard-sync-settings";
import { PageShell } from "@/components/page-shell";
import { getTeam } from "@/lib/api-team";
import { requireSession } from "@/lib/server-session";
import styles from "./settings.module.css";

export default async function SettingsPage() {
  const session = await requireSession();
  const workspace = session.workspaces[0];
  const team =
    workspace?.role === "owner" ? await getTeam(workspace.id).catch(() => null) : null;

  return (
    <PageShell title="Settings" subtitle="Account and workspace preferences">
      <div className={styles.grid}>
        <section className={styles.card}>
          <h2>Account</h2>
          <dl>
            <div>
              <dt>Email</dt>
              <dd>{session.user.email}</dd>
            </div>
            {session.user.name && (
              <div>
                <dt>Name</dt>
                <dd>{session.user.name}</dd>
              </div>
            )}
          </dl>
        </section>
        {workspace && (
          <section className={styles.card}>
            <h2>Workspace</h2>
            <dl>
              <div>
                <dt>Name</dt>
                <dd>{workspace.name}</dd>
              </div>
              <div>
                <dt>Plan</dt>
                <dd>{workspace.plan_sku}</dd>
              </div>
              {workspace.role === "owner" && team && (
                <div>
                  <dt>Members</dt>
                  <dd>
                    {team.member_count} / {team.member_limit}
                    {team.pending_count > 0 ? ` (${team.pending_count} pending)` : ""}
                  </dd>
                </div>
              )}
              <div>
                <dt>Your role</dt>
                <dd>{workspace.role}</dd>
              </div>
            </dl>
          </section>
        )}
        <DashboardSyncSettings />
      </div>
    </PageShell>
  );
}
