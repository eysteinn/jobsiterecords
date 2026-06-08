import type { Item, ItemTag, Job, JobBundle, MediaFile, Tag } from "@/lib/api-jobs";

export type CursorPollResult = {
  changed: boolean;
  etag: string | null;
  cursor: string | null;
};

export async function pollJobCursor(jobId: string, etag: string | null): Promise<CursorPollResult> {
  const res = await fetch(`/api/jobs/${jobId}/cursor`, {
    headers: etag ? { "If-None-Match": etag } : {},
    cache: "no-store",
  });
  if (res.status === 304) {
    return { changed: false, etag, cursor: null };
  }
  if (!res.ok) {
    throw new Error("Cursor poll failed");
  }
  const data = (await res.json()) as { cursor: string };
  const nextEtag = res.headers.get("ETag");
  return { changed: true, etag: nextEtag, cursor: data.cursor };
}

export async function pollWorkspaceCursor(
  workspaceId: string,
  etag: string | null,
): Promise<CursorPollResult> {
  const res = await fetch(`/api/workspaces/${workspaceId}/cursor`, {
    headers: etag ? { "If-None-Match": etag } : {},
    cache: "no-store",
  });
  if (res.status === 304) {
    return { changed: false, etag, cursor: null };
  }
  if (!res.ok) {
    throw new Error("Cursor poll failed");
  }
  const data = (await res.json()) as { cursor: string };
  const nextEtag = res.headers.get("ETag");
  return { changed: true, etag: nextEtag, cursor: data.cursor };
}

export async function fetchJobDelta(jobId: string, since: string): Promise<JobBundle> {
  const q = `?since=${encodeURIComponent(since)}`;
  const res = await fetch(`/api/jobs/${jobId}${q}`, { cache: "no-store" });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.message || "Delta fetch failed");
  }
  return data as JobBundle;
}

export function mergeJobBundle(
  items: Item[],
  mediaFiles: MediaFile[],
  delta: JobBundle,
  tags: Tag[] = [],
  itemTags: ItemTag[] = [],
): {
  items: Item[];
  mediaFiles: MediaFile[];
  tags: Tag[];
  itemTags: ItemTag[];
  job: Job | null;
  added: number;
  jobDeleted: boolean;
} {
  const itemMap = new Map(items.map((it) => [it.id, it]));
  let added = 0;
  for (const raw of delta.items ?? []) {
    const it = raw as Item & { deleted_at?: string | null };
    if (it.deleted_at) {
      itemMap.delete(it.id);
      continue;
    }
    if (!itemMap.has(it.id)) added++;
    itemMap.set(it.id, it);
  }

  const mediaMap = new Map(mediaFiles.map((m) => [m.id, m]));
  for (const raw of delta.media_files ?? []) {
    const mf = raw as MediaFile & { deleted_at?: string | null };
    if (mf.deleted_at) {
      mediaMap.delete(mf.id);
      continue;
    }
    if (!mediaMap.has(mf.id) && mf.status === "uploaded") added++;
    mediaMap.set(mf.id, mf);
  }

  const mergedItems = [...itemMap.values()].sort(
    (a, b) => new Date(b.captured_at).getTime() - new Date(a.captured_at).getTime(),
  );

  const tagMap = new Map(tags.map((tag) => [tag.id, tag]));
  for (const tag of delta.tags ?? []) tagMap.set(tag.id, tag);

  const itemTagMap = new Map(itemTags.map((link) => [`${link.item_id}:${link.tag_id}`, link]));
  const deltaItemIds = new Set((delta.items ?? []).map((item) => item.id));
  if (deltaItemIds.size > 0) {
    for (const key of [...itemTagMap.keys()]) {
      const itemId = key.split(":")[0];
      if (deltaItemIds.has(itemId)) itemTagMap.delete(key);
    }
  }
  for (const link of delta.item_tags ?? []) {
    itemTagMap.set(`${link.item_id}:${link.tag_id}`, link);
  }

  const rawJob = delta.job as (Job & { deleted_at?: string | null }) | undefined;
  const job = rawJob?.deleted_at ? null : (rawJob ?? null);

  return {
    items: mergedItems,
    mediaFiles: [...mediaMap.values()],
    tags: [...tagMap.values()].sort((a, b) => a.name.localeCompare(b.name)),
    itemTags: [...itemTagMap.values()],
    job,
    added,
    jobDeleted: Boolean(rawJob?.deleted_at),
  };
}
