/** Deterministic UTC formatters (no Intl — avoids Node vs browser hydration mismatch). */

const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
] as const;

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function parseUtc(iso: string): Date | null {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function formatDateTime(iso: string): string {
  const d = parseUtc(iso);
  if (!d) return "—";
  return `${pad2(d.getUTCDate())}/${pad2(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}, ${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}`;
}

export function formatTime(iso: string): string {
  const d = parseUtc(iso);
  if (!d) return "—";
  return `${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}`;
}

export function formatDate(iso: string): string {
  const d = parseUtc(iso);
  if (!d) return "—";
  return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

export function formatDayKey(iso: string): string {
  const d = parseUtc(iso);
  if (!d) return iso.slice(0, 10);
  return d.toISOString().slice(0, 10);
}

/** Relative time for mobile cards (e.g. "2d ago", "Updated 03/06/2026 22:51"). */
export function formatRelativeTime(iso: string): string {
  const d = parseUtc(iso);
  if (!d) return "—";
  const now = Date.now();
  const diffMs = now - d.getTime();
  const diffMin = Math.floor(diffMs / 60_000);
  if (diffMin < 1) return "Just now";
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 7) return `${diffDay}d ago`;
  return formatDateTime(iso);
}

export function formatUpdatedLabel(iso: string): string {
  const d = parseUtc(iso);
  if (!d) return "—";
  const now = Date.now();
  const diffDay = Math.floor((now - d.getTime()) / 86_400_000);
  if (diffDay < 7) return `Updated ${formatRelativeTime(iso)}`;
  return `Updated ${formatDateTime(iso)}`;
}
