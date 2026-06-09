/** Browser media capture helpers for mobile web. */

export function hasCameraCapture(): boolean {
  if (typeof navigator === "undefined") return false;
  return Boolean(navigator.mediaDevices?.getUserMedia);
}

export function hasVoiceCapture(): boolean {
  if (typeof window === "undefined") return false;
  return typeof MediaRecorder !== "undefined" && hasCameraCapture();
}

const VOICE_MIME_CANDIDATES = [
  "audio/mp4",
  "audio/webm;codecs=opus",
  "audio/webm",
  "audio/aac",
] as const;

export function pickVoiceRecorderMime(): string | null {
  if (typeof MediaRecorder === "undefined") return null;
  for (const mime of VOICE_MIME_CANDIDATES) {
    if (MediaRecorder.isTypeSupported(mime)) return mime;
  }
  return null;
}

/** Normalize recorder mime for API upload (strip codec suffix). */
export function normalizeVoiceMime(mime: string): string {
  const base = mime.split(";")[0]?.trim().toLowerCase() ?? mime;
  if (base === "audio/x-m4a") return "audio/mp4";
  return base;
}

export function loadImageDimensions(blob: Blob): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve({ width: img.naturalWidth, height: img.naturalHeight });
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read photo"));
    };
    img.src = url;
  });
}

export async function blobFromCanvas(
  canvas: HTMLCanvasElement,
  quality = 0.92,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("Could not encode photo"))),
      "image/jpeg",
      quality,
    );
  });
}
