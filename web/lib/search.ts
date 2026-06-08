import type { Item, Job, MediaFile } from "@/lib/api-jobs";

export type ItemKind = Item["kind"];
export type JobStatus = Job["status"];

export function normalizeSearch(query: string | null | undefined): string | null {
  const trimmed = query?.trim();
  return trimmed ? trimmed.toLowerCase() : null;
}

function includes(haystack: string | null | undefined, needle: string): boolean {
  if (!haystack) return false;
  return haystack.toLowerCase().includes(needle);
}

export function filterJobs(
  jobs: Job[],
  query: string | null | undefined,
  statuses?: ReadonlySet<JobStatus>,
): Job[] {
  let result = jobs;
  if (statuses && statuses.size > 0) {
    result = result.filter((job) => statuses.has(job.status));
  }
  const search = normalizeSearch(query);
  if (!search) return result;
  return result.filter(
    (job) =>
      includes(job.name, search) ||
      includes(job.client_name, search) ||
      includes(job.address, search) ||
      includes(job.job_number, search),
  );
}

export function itemMatchesSearch(item: Item, media: MediaFile[], search: string): boolean {
  if (includes(item.caption, search)) return true;
  if (includes(item.body, search)) return true;
  for (const file of media) {
    if (includes(file.original_filename, search)) return true;
  }
  return false;
}

export function filterTimelineItems(
  items: Item[],
  mediaByItem: Map<string, MediaFile[]>,
  query: string | null | undefined,
  kinds?: ReadonlySet<ItemKind>,
): Item[] {
  let result = items;
  if (kinds && kinds.size > 0) {
    result = result.filter((item) => kinds.has(item.kind));
  }
  const search = normalizeSearch(query);
  if (!search) return result;
  return result.filter((item) => itemMatchesSearch(item, mediaByItem.get(item.id) ?? [], search));
}

export function fuzzyScore(text: string, query: string): number {
  const hay = text.toLowerCase();
  const needle = query.toLowerCase().trim();
  if (!needle) return 1;
  if (hay === needle) return 100;
  if (hay.startsWith(needle)) return 80;
  if (hay.includes(needle)) return 60;
  let hi = 0;
  let score = 0;
  for (const ch of needle) {
    const idx = hay.indexOf(ch, hi);
    if (idx < 0) return 0;
    score += 10 - Math.min(idx - hi, 9);
    hi = idx + 1;
  }
  return score;
}
