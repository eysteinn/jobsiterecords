"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { blobFromCanvas, hasCameraCapture, loadImageDimensions } from "@/lib/capture-support";
import { saveCapturedPhoto } from "@/lib/save-captured-item";
import type { Item, MediaFile } from "@/lib/api-jobs";
import styles from "./mobile-photo-capture.module.css";

type Phase = "camera" | "review" | "fallback";

type Props = {
  open: boolean;
  jobId: string;
  onClose: () => void;
  onSaved: (item: Item, media: MediaFile) => void;
};

export function MobilePhotoCapture({ open, jobId, onClose, onSaved }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [phase, setPhase] = useState<Phase>("camera");
  const [facingMode, setFacingMode] = useState<"environment" | "user">("environment");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [photoBlob, setPhotoBlob] = useState<Blob | null>(null);
  const [caption, setCaption] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [cameraReady, setCameraReady] = useState(false);

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    setCameraReady(false);
  }, []);

  const startCamera = useCallback(async (facing: "environment" | "user") => {
    if (!hasCameraCapture()) {
      setPhase("fallback");
      return;
    }
    stopStream();
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: facing },
        audio: false,
      });
      streamRef.current = stream;
      const video = videoRef.current;
      if (video) {
        video.srcObject = stream;
        await video.play();
      }
      setCameraReady(true);
      setPhase("camera");
    } catch {
      setPhase("fallback");
      setError("Camera access denied. Choose a photo from your library instead.");
    }
  }, [stopStream]);

  useEffect(() => {
    if (!open) return;
    setPhase("camera");
    setCaption("");
    setPhotoBlob(null);
    setPreviewUrl(null);
    setError(null);
    setSaving(false);
    void startCamera(facingMode);
    return () => {
      stopStream();
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- reset when dialog opens
  }, [open]);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape" && !saving) onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose, saving]);

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  async function switchCamera() {
    const next = facingMode === "environment" ? "user" : "environment";
    setFacingMode(next);
    await startCamera(next);
  }

  async function captureFrame() {
    const video = videoRef.current;
    if (!video || !cameraReady) return;
    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.drawImage(video, 0, 0);
    try {
      const blob = await blobFromCanvas(canvas);
      stopStream();
      if (previewUrl) URL.revokeObjectURL(previewUrl);
      const url = URL.createObjectURL(blob);
      setPreviewUrl(url);
      setPhotoBlob(blob);
      setPhase("review");
    } catch {
      setError("Could not capture photo");
    }
  }

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    stopStream();
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    setPhotoBlob(file);
    setPhase("review");
    setError(null);
  }

  function retake() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setPhotoBlob(null);
    setCaption("");
    setError(null);
    void startCamera(facingMode);
  }

  async function save() {
    if (!photoBlob) return;
    setSaving(true);
    setError(null);
    try {
      const dims = await loadImageDimensions(photoBlob);
      const { item, media } = await saveCapturedPhoto({
        jobId,
        blob: photoBlob,
        caption,
        width: dims.width,
        height: dims.height,
      });
      onSaved(item, media);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save photo");
    } finally {
      setSaving(false);
    }
  }

  if (!open) return null;

  if (phase === "review" && previewUrl) {
    return (
      <div className={styles.overlay} role="dialog" aria-modal="true" aria-label="Review photo">
        <div className={styles.review}>
          <img src={previewUrl} alt="Captured photo preview" className={styles.stillPreview} />
          <div className={styles.reviewForm}>
            <label>
              Caption (optional)
              <input
                type="text"
                value={caption}
                onChange={(e) => setCaption(e.target.value)}
                placeholder="Add a caption"
                maxLength={160}
              />
            </label>
            {error && (
              <p className={styles.error} role="alert">
                {error}
              </p>
            )}
            <div className={styles.reviewActions}>
              <button type="button" className={styles.retakeBtn} disabled={saving} onClick={retake}>
                Retake
              </button>
              <button type="button" className={styles.saveBtn} disabled={saving} onClick={save}>
                {saving ? "Saving…" : "Save photo"}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (phase === "fallback") {
    return (
      <div className={styles.overlay} role="dialog" aria-modal="true" aria-label="Add photo">
        <header className={styles.header}>
          <button type="button" className={styles.headerBtn} onClick={onClose}>
            Cancel
          </button>
          <h2 className={styles.headerTitle}>Add photo</h2>
          <span style={{ width: 60 }} aria-hidden />
        </header>
        <div className={styles.fallback}>
          <p>{error ?? "Choose a photo from your camera or photo library."}</p>
          <button
            type="button"
            className={styles.fallbackBtn}
            onClick={() => fileInputRef.current?.click()}
          >
            Take or choose photo
          </button>
        </div>
        <input
          ref={fileInputRef}
          className={styles.hiddenInput}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={handleFileChange}
        />
      </div>
    );
  }

  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-label="Take photo">
      <header className={styles.header}>
        <button type="button" className={styles.headerBtn} onClick={onClose}>
          Cancel
        </button>
        <h2 className={styles.headerTitle}>Take photo</h2>
        <span style={{ width: 60 }} aria-hidden />
      </header>

      <div className={styles.previewWrap}>
        <video ref={videoRef} className={styles.video} playsInline muted autoPlay />
      </div>

      {error && (
        <p className={styles.error} role="alert">
          {error}
        </p>
      )}

      <div className={styles.controls}>
        <button
          type="button"
          className={styles.sideBtn}
          aria-label="Choose from library"
          onClick={() => fileInputRef.current?.click()}
        >
          <GalleryIcon />
        </button>
        <button
          type="button"
          className={styles.shutter}
          aria-label="Take photo"
          disabled={!cameraReady}
          onClick={captureFrame}
        >
          <div className={styles.shutterInner} />
        </button>
        <button
          type="button"
          className={styles.sideBtn}
          aria-label="Switch camera"
          disabled={!cameraReady}
          onClick={switchCamera}
        >
          <FlipIcon />
        </button>
      </div>

      <input
        ref={fileInputRef}
        className={styles.hiddenInput}
        type="file"
        accept="image/*"
        onChange={handleFileChange}
      />
    </div>
  );
}

function GalleryIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <path d="M21 15l-5-5L5 21" />
    </svg>
  );
}

function FlipIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M3 7h6M3 7l3-3M3 7l3 3" />
      <path d="M21 17h-6M21 17l-3 3M21 17l-3-3" />
      <rect x="7" y="5" width="10" height="14" rx="2" />
    </svg>
  );
}
