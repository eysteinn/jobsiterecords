import type { Item, Job, MediaFile, Tag } from "@/lib/api-jobs";

export type ItemKind = Item["kind"];
export type JobStatus = Job["status"];

const KIND_LABELS: Record<ItemKind, string> = {
  photo: "Photos",
  voice: "Voice",
  note: "Notes",
  file: "Files",
};

export function kindLabel(kind: ItemKind): string {
  return KIND_LABELS[kind];
}

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

export function buildTagsByItem(
  tags: Tag[],
  itemTags: { item_id: string; tag_id: string }[],
): Map<string, Tag[]> {
  const tagById = new Map(tags.map((tag) => [tag.id, tag]));
  const map = new Map<string, Tag[]>();
  for (const link of itemTags) {
    const tag = tagById.get(link.tag_id);
    if (!tag) continue;
    const list = map.get(link.item_id) ?? [];
    list.push(tag);
    map.set(link.item_id, list);
  }
  return map;
}

export function itemMatchesSearch(
  item: Item,
  media: MediaFile[],
  itemTags: Tag[],
  search: string,
): boolean {
  if (includes(item.caption, search)) return true;
  if (includes(item.body, search)) return true;
  for (const tag of itemTags) {
    if (includes(tag.name, search)) return true;
  }
  for (const file of media) {
    if (includes(file.original_filename, search)) return true;
  }
  return false;
}

export function itemMatchesTagFilter(itemTags: Tag[], tagIds: ReadonlySet<string>): boolean {
  if (tagIds.size === 0) return true;
  return itemTags.some((tag) => tagIds.has(tag.id));
}

export function filterTimelineItems(
  items: Item[],
  mediaByItem: Map<string, MediaFile[]>,
  tagsByItem: Map<string, Tag[]>,
  query: string | null | undefined,
  kinds?: ReadonlySet<ItemKind>,
  tagIds?: ReadonlySet<string>,
): Item[] {
  let result = items;
  if (kinds && kinds.size > 0) {
    result = result.filter((item) => kinds.has(item.kind));
  }
  if (tagIds && tagIds.size > 0) {
    result = result.filter((item) => itemMatchesTagFilter(tagsByItem.get(item.id) ?? [], tagIds));
  }
  const search = normalizeSearch(query);
  if (!search) return result;
  return result.filter((item) =>
    itemMatchesSearch(item, mediaByItem.get(item.id) ?? [], tagsByItem.get(item.id) ?? [], search),
  );
}

export function tagsUsedInJob(tagsByItem: Map<string, Tag[]>, items: Item[]): Set<string> {
  const itemIds = new Set(items.map((item) => item.id));
  const ids = new Set<string>();
  for (const [itemId, itemTags] of tagsByItem) {
    if (!itemIds.has(itemId)) continue;
    for (const tag of itemTags) ids.add(tag.id);
  }
  return ids;
}

export function quickTagsForJob(allTags: Tag[], tagsInJob: ReadonlySet<string>, limit = 6): Tag[] {
  return allTags.filter((tag) => tagsInJob.has(tag.id)).slice(0, limit);
}

export function buildActiveFilterLabels(
  query: string,
  kinds: ReadonlySet<ItemKind>,
  tagIds: ReadonlySet<string>,
  tags: Tag[],
): string[] {
  const parts: string[] = [];
  const search = normalizeSearch(query);
  if (search) parts.push(`"${search}"`);
  for (const kind of (["photo", "voice", "note", "file"] as const)) {
    if (kinds.has(kind)) parts.push(kindLabel(kind));
  }
  for (const tag of tags) {
    if (tagIds.has(tag.id)) parts.push(tag.name);
  }
  return parts;
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
