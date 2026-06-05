import type { Item, MediaFile } from "./api-jobs";
import {
  cloneShapes,
  decodeDocument,
  encodeDocument,
  renderJpeg,
  type PhotoAnnotationDocument,
} from "./photo-annotation";
import { completeMediaUpload, deleteMediaFile, mintMediaUpload, putBlob } from "./media-upload";
import { mediaDownloadUrl } from "./photo-media";

export async function savePhotoAnnotations({
  jobId,
  item,
  media,
  document,
}: {
  jobId: string;
  item: Item;
  media: MediaFile[];
  document: PhotoAnnotationDocument;
}): Promise<MediaFile[]> {
  const primary = media.find((m) => m.role === "primary_photo" && m.status === "uploaded");
  if (!primary) throw new Error("Original photo not available");

  const existingOverlay = media.find((m) => m.role === "annotation_overlay");
  const existingRender = media.find((m) => m.role === "annotated_render");
  const toDelete = [existingOverlay?.id, existingRender?.id].filter(Boolean) as string[];

  const kept = media.filter((m) => !toDelete.includes(m.id));

  if (document.shapes.length === 0) {
    for (const id of toDelete) {
      await deleteMediaFile(id);
    }
    await bumpItem(jobId, item);
    return kept.filter((m) => m.role !== "annotation_overlay" && m.role !== "annotated_render");
  }

  const imgRes = await fetch(mediaDownloadUrl(primary.id));
  if (!imgRes.ok) throw new Error("Could not load original photo");
  const imgBlob = await imgRes.blob();
  const imgUrl = URL.createObjectURL(imgBlob);
  let jpegBlob: Blob;
  try {
    const img = await loadImage(imgUrl);
    jpegBlob = await renderJpeg(img, img.naturalWidth, img.naturalHeight, document.shapes);
  } finally {
    URL.revokeObjectURL(imgUrl);
  }

  const jsonBlob = new Blob([encodeDocument({ ...document, shapes: cloneShapes(document.shapes) })], {
    type: "application/json",
  });

  const overlayId = crypto.randomUUID();
  const renderId = crypto.randomUUID();

  const overlayMint = await mintMediaUpload(item.id, {
    id: overlayId,
    role: "annotation_overlay",
    mime_type: "application/json",
    size_bytes: jsonBlob.size,
  });
  const overlayEtag = await putBlob(overlayMint.upload_url, jsonBlob, "application/json");
  const overlayMedia = await completeMediaUpload(overlayId, jsonBlob.size, overlayEtag);

  const renderMint = await mintMediaUpload(item.id, {
    id: renderId,
    role: "annotated_render",
    mime_type: "image/jpeg",
    size_bytes: jpegBlob.size,
    width: primary.width ?? undefined,
    height: primary.height ?? undefined,
  });
  const renderEtag = await putBlob(renderMint.upload_url, jpegBlob, "image/jpeg");
  const renderMedia = await completeMediaUpload(renderId, jpegBlob.size, renderEtag);

  for (const id of toDelete) {
    await deleteMediaFile(id);
  }

  await bumpItem(jobId, item);

  return [...kept, overlayMedia, renderMedia];
}

async function bumpItem(jobId: string, item: Item): Promise<void> {
  const now = new Date().toISOString();
  const res = await fetch(`/api/jobs/${jobId}/items/${item.id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      kind: item.kind,
      body: item.body,
      caption: item.caption,
      captured_at: item.captured_at,
      created_at: item.created_at,
      updated_at: now,
    }),
  });
  if (!res.ok) {
    const data = await res.json();
    throw new Error(data.message || "Could not update item");
  }
}

function loadImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Could not decode photo"));
    img.src = url;
  });
}

export async function fetchAnnotationDocument(overlayMediaId: string): Promise<PhotoAnnotationDocument | null> {
  const res = await fetch(mediaDownloadUrl(overlayMediaId, false));
  if (!res.ok) return null;
  const text = await res.text();
  return decodeDocument(text);
}
