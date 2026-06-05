import type { MediaFile } from "./api-jobs";

export type PhotoMediaSet = {
  /** Annotated render when present, otherwise the original photo. */
  display: MediaFile | undefined;
  /** Original capture — only set when an annotated render exists. */
  original: MediaFile | undefined;
  hasAnnotations: boolean;
  overlay?: MediaFile;
  primary?: MediaFile;
};

/** Resolve display/original photo media for a timeline item (matches mobile TimelineItem). */
export function getPhotoMedia(media: MediaFile[]): PhotoMediaSet {
  const uploaded = media.filter((m) => m.status === "uploaded");
  const annotated = uploaded.find((m) => m.role === "annotated_render");
  const overlay = uploaded.find((m) => m.role === "annotation_overlay");
  const primary = uploaded.find((m) => m.role === "primary_photo");
  const display = annotated ?? primary ?? uploaded[0];
  const hasAnnotations = annotated != null || overlay != null;
  return {
    display,
    original: hasAnnotations && primary ? primary : undefined,
    hasAnnotations,
    overlay,
    primary,
  };
}

export function mediaDownloadUrl(mediaId: string, inline = true) {
  return `/api/media/${mediaId}/download${inline ? "?inline=1" : ""}`;
}

/** Item thumb URL — bust cache when display media changes (e.g. after annotation save). */
export function itemThumbUrl(itemId: string, display?: MediaFile, width = 384) {
  const params = new URLSearchParams({ w: String(width) });
  if (display?.updated_at) {
    params.set("v", display.updated_at);
  } else if (display?.id) {
    params.set("v", display.id);
  }
  return `/api/items/${itemId}/thumb?${params.toString()}`;
}
