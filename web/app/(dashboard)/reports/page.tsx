import { EmptyState, PageShell } from "@/components/page-shell";

export default function ReportsPage() {
  return (
    <PageShell title="Reports" subtitle="PDF reports for client handoff">
      <EmptyState
        title="No reports yet"
        description="Generate branded PDF reports from job timelines. Reports ship in M7."
      />
    </PageShell>
  );
}
