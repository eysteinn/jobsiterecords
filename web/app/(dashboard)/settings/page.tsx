import { PageShell } from "@/components/page-shell";
import { requireSession } from "@/lib/server-session";
import styles from "./settings.module.css";

export default async function SettingsPage() {
  const session = await requireSession();
  const workspace = session.workspaces[0];

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
              <div>
                <dt>Your role</dt>
                <dd>{workspace.role}</dd>
              </div>
            </dl>
          </section>
        )}
      </div>
    </PageShell>
  );
}
