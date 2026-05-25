import { EmptyState, PageShell } from "@/components/page-shell";
import styles from "@/components/page-shell.module.css";

export default function JobsPage() {
  return (
    <PageShell
      title="Jobs"
      subtitle="Synced job records for this workspace"
      action={
        <button type="button" className={styles.primaryDisabled} disabled>
          + New job
        </button>
      }
    >
      <EmptyState
        title="No jobs in this workspace yet"
        description="Jobs will appear here after you create them on the dashboard or sync from the mobile app. Job creation ships in M2."
      />
    </PageShell>
  );
}
