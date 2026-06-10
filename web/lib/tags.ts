import type { Item, ItemTag, Tag } from "./api-jobs";

export function tagIdsForItem(itemTags: ItemTag[], itemId: string): Set<string> {
  const ids = new Set<string>();
  for (const link of itemTags) {
    if (link.item_id === itemId) ids.add(link.tag_id);
  }
  return ids;
}

export function buildItemTagsMap(itemTags: ItemTag[], itemIds: Iterable<string>): Map<string, Set<string>> {
  const map = new Map<string, Set<string>>();
  for (const itemId of itemIds) {
    map.set(itemId, tagIdsForItem(itemTags, itemId));
  }
  return map;
}

export function tagCoverageForItemTags(
  itemTagsMap: Map<string, Set<string>>,
  selectedItemIds: ReadonlySet<string>,
): { all: Set<string>; partial: Set<string> } {
  const all = new Set<string>();
  const partial = new Set<string>();
  const selected = [...selectedItemIds];
  if (selected.length === 0) return { all, partial };

  const tagIds = new Set<string>();
  for (const itemId of selected) {
    for (const tagId of itemTagsMap.get(itemId) ?? []) {
      tagIds.add(tagId);
    }
  }

  for (const tagId of tagIds) {
    let count = 0;
    for (const itemId of selected) {
      if (itemTagsMap.get(itemId)?.has(tagId)) count++;
    }
    if (count === selected.length) all.add(tagId);
    else partial.add(tagId);
  }
  return { all, partial };
}

export function itemTagLinksForItem(itemId: string, tagIds: Iterable<string>): ItemTag[] {
  return [...tagIds].map((tag_id) => ({ item_id: itemId, tag_id }));
}

export function mergeItemTags(
  itemTags: ItemTag[],
  itemId: string,
  nextTagIds: Set<string>,
): ItemTag[] {
  const withoutItem = itemTags.filter((link) => link.item_id !== itemId);
  return [...withoutItem, ...itemTagLinksForItem(itemId, nextTagIds)];
}

export function mergeBulkItemTags(
  itemTags: ItemTag[],
  itemTagSets: Map<string, Set<string>>,
): ItemTag[] {
  const itemIds = new Set(itemTagSets.keys());
  const kept = itemTags.filter((link) => !itemIds.has(link.item_id));
  const added: ItemTag[] = [];
  for (const [itemId, tagIds] of itemTagSets) {
    added.push(...itemTagLinksForItem(itemId, tagIds));
  }
  return [...kept, ...added];
}

type ItemPutBody = {
  kind: string;
  body?: string | null;
  caption?: string | null;
  captured_at: string;
  created_at: string;
  updated_at: string;
  tag_ids?: string[];
};

export function buildItemPutBody(item: Item, tagIds?: string[]): ItemPutBody {
  const body: ItemPutBody = {
    kind: item.kind,
    body: item.body,
    caption: item.caption,
    captured_at: item.captured_at,
    created_at: item.created_at,
    updated_at: new Date().toISOString(),
  };
  if (tagIds) body.tag_ids = tagIds;
  return body;
}

export async function upsertWorkspaceTag(workspaceId: string, name: string, tagId?: string): Promise<Tag> {
  const id = tagId ?? crypto.randomUUID();
  const res = await fetch(`/api/workspaces/${workspaceId}/tags/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: name.trim() }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || "Could not save tag");
  return data as Tag;
}

export async function saveItemTagIds(jobId: string, item: Item, tagIds: string[]): Promise<Item> {
  const res = await fetch(`/api/jobs/${jobId}/items/${item.id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(buildItemPutBody(item, tagIds)),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || "Could not save tags");
  return data as Item;
}
