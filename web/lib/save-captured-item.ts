import type { Item, MediaFile } from "./api-jobs";
import { completeMediaUpload, mintMediaUpload, putBlob } from "./media-upload";

type SavePhotoInput = {
  jobId: string;
  blob: Blob;
  caption?: string | null;
  tagIds?: string[];
  width?: number;
  height?: number;
};

type SaveVoiceInput = {
  jobId: string;
  blob: Blob;
  mimeType: string;
  durationMs: number;
  caption?: string | null;
  tagIds?: string[];
};

async function upsertItem(
  jobId: string,
  itemId: string,
  body: Record<string, unknown>,
): Promise<Item> {
  const res = await fetch(`/api/jobs/${jobId}/items/${itemId}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || "Could not save item");
  return data as Item;
}

async function uploadMedia(
  itemId: string,
  mediaId: string,
  role: string,
  blob: Blob,
  mimeType: string,
  extra?: { width?: number; height?: number; durationMs?: number },
): Promise<MediaFile> {
  const mint = await mintMediaUpload(itemId, {
    id: mediaId,
    role,
    mime_type: mimeType,
    size_bytes: blob.size,
    width: extra?.width,
    height: extra?.height,
    duration_ms: extra?.durationMs,
  });
  const etag = await putBlob(mint.upload_url, blob, mimeType);
  return completeMediaUpload(mediaId, blob.size, etag);
}

export async function saveCapturedPhoto({
  jobId,
  blob,
  caption,
  tagIds,
  width,
  height,
}: SavePhotoInput): Promise<{ item: Item; media: MediaFile }> {
  const itemId = crypto.randomUUID();
  const mediaId = crypto.randomUUID();
  const now = new Date().toISOString();

  const item = await upsertItem(jobId, itemId, {
    kind: "photo",
    caption: caption?.trim() || null,
    captured_at: now,
    created_at: now,
    updated_at: now,
    ...(tagIds && tagIds.length > 0 ? { tag_ids: tagIds } : {}),
  });

  const media = await uploadMedia(itemId, mediaId, "primary_photo", blob, "image/jpeg", {
    width,
    height,
  });

  return { item, media };
}

export async function saveCapturedVoice({
  jobId,
  blob,
  mimeType,
  durationMs,
  caption,
  tagIds,
}: SaveVoiceInput): Promise<{ item: Item; media: MediaFile }> {
  const itemId = crypto.randomUUID();
  const mediaId = crypto.randomUUID();
  const now = new Date().toISOString();

  const item = await upsertItem(jobId, itemId, {
    kind: "voice",
    caption: caption?.trim() || null,
    captured_at: now,
    created_at: now,
    updated_at: now,
    ...(tagIds && tagIds.length > 0 ? { tag_ids: tagIds } : {}),
  });

  const media = await uploadMedia(itemId, mediaId, "voice_note", blob, mimeType, {
    durationMs,
  });

  return { item, media };
}
