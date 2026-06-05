import type { MediaFile } from "./api-jobs";

type MintResponse = {
  media_file_id: string;
  upload_url: string;
  storage_key: string;
};

type CompleteResponse = {
  media_file: MediaFile;
};

export async function mintMediaUpload(
  itemId: string,
  body: {
    id: string;
    role: string;
    mime_type: string;
    size_bytes: number;
    width?: number;
    height?: number;
  },
): Promise<MintResponse> {
  const res = await fetch(`/api/items/${itemId}/media-files`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || "Could not start upload");
  return data as MintResponse;
}

export async function putBlob(uploadUrl: string, blob: Blob, mimeType: string): Promise<string | null> {
  const res = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": mimeType },
    body: blob,
  });
  if (!res.ok) throw new Error("Blob upload failed");
  return res.headers.get("etag");
}

export async function completeMediaUpload(
  mediaId: string,
  sizeBytes: number,
  etag?: string | null,
): Promise<MediaFile> {
  const res = await fetch(`/api/media/${mediaId}/complete`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ etag: etag ?? "", size_bytes: sizeBytes }),
  });
  const data = (await res.json()) as CompleteResponse;
  if (!res.ok) throw new Error((data as { message?: string }).message || "Could not complete upload");
  return data.media_file;
}

export async function deleteMediaFile(mediaId: string): Promise<void> {
  const res = await fetch(`/api/media/${mediaId}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    const data = await res.json().catch(() => ({ message: "Delete failed" }));
    throw new Error(data.message || "Could not delete media");
  }
}
