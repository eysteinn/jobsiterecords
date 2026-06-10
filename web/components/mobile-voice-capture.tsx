"use client";

import { useEffect, useRef, useState } from "react";
import { formatDuration } from "@/lib/format";
import {
  hasVoiceCapture,
  normalizeVoiceMime,
  pickVoiceRecorderMime,
} from "@/lib/capture-support";
import { saveCapturedVoice } from "@/lib/save-captured-item";
import type { Item, MediaFile } from "@/lib/api-jobs";
import styles from "./mobile-voice-capture.module.css";

type Phase = "record" | "review" | "unsupported";

const MAX_DURATION_MS = 10 * 60 * 1000;
const BAR_COUNT = 24;

type Props = {
  open: boolean;
  jobId: string;
  onClose: () => void;
  onSaved: (item: Item, media: MediaFile) => void;
};

export function MobileVoiceCapture({ open, jobId, onClose, onSaved }: Props) {
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const timerRef = useRef<number | null>(null);
  const startTimeRef = useRef<number>(0);
  const elapsedRef = useRef(0);

  const [phase, setPhase] = useState<Phase>("record");
  const [recording, setRecording] = useState(false);
  const [elapsedMs, setElapsedMs] = useState(0);
  const [levels, setLevels] = useState<number[]>(() => Array(BAR_COUNT).fill(0.15));
  const [mimeType, setMimeType] = useState<string | null>(null);
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [caption, setCaption] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function stopStream() {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
  }

  function clearTimer() {
    if (timerRef.current !== null) {
      window.clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }

  function resetRecording() {
    clearTimer();
    recorderRef.current = null;
    chunksRef.current = [];
    stopStream();
    setRecording(false);
    setElapsedMs(0);
    elapsedRef.current = 0;
    setLevels(Array(BAR_COUNT).fill(0.15));
    if (audioUrl) URL.revokeObjectURL(audioUrl);
    setAudioUrl(null);
    setAudioBlob(null);
  }

  useEffect(() => {
    if (!open) return;
    resetRecording();
    setCaption("");
    setError(null);
    setSaving(false);
    const mime = pickVoiceRecorderMime();
    setMimeType(mime);
    setPhase(mime && hasVoiceCapture() ? "record" : "unsupported");
    return () => {
      resetRecording();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- reset when dialog opens
  }, [open]);

  useEffect(() => {
    return () => {
      if (audioUrl) URL.revokeObjectURL(audioUrl);
    };
  }, [audioUrl]);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape" && !saving && !recording) onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose, saving, recording]);

  async function startRecording() {
    if (!mimeType) return;
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      const recorder = new MediaRecorder(stream, { mimeType });
      chunksRef.current = [];
      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mimeType });
        stopStream();
        if (audioUrl) URL.revokeObjectURL(audioUrl);
        const url = URL.createObjectURL(blob);
        setAudioUrl(url);
        setAudioBlob(blob);
        setPhase("review");
        setRecording(false);
        clearTimer();
      };
      recorderRef.current = recorder;
      recorder.start(250);
      startTimeRef.current = Date.now();
      setRecording(true);
      timerRef.current = window.setInterval(() => {
        const next = elapsedRef.current + (Date.now() - startTimeRef.current);
        if (next >= MAX_DURATION_MS) {
          stopRecording();
          return;
        }
        setElapsedMs(next);
        setLevels((prev) => {
          const level = 0.2 + Math.random() * 0.8;
          return [...prev.slice(1), level];
        });
      }, 200);
    } catch {
      setError("Microphone access denied");
    }
  }

  function stopRecording() {
    if (!recorderRef.current || recorderRef.current.state === "inactive") return;
    elapsedRef.current += Date.now() - startTimeRef.current;
    setElapsedMs(elapsedRef.current);
    recorderRef.current.stop();
  }

  function discard() {
    resetRecording();
    setPhase("record");
    setError(null);
  }

  async function save() {
    if (!audioBlob || !mimeType) return;
    setSaving(true);
    setError(null);
    try {
      const normalizedMime = normalizeVoiceMime(mimeType);
      const { item, media } = await saveCapturedVoice({
        jobId,
        blob: audioBlob,
        mimeType: normalizedMime,
        durationMs: elapsedMs,
        caption,
      });
      onSaved(item, media);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save voice note");
    } finally {
      setSaving(false);
    }
  }

  if (!open) return null;

  if (phase === "unsupported") {
    return (
      <div className={styles.overlay} role="dialog" aria-modal="true" aria-label="Voice note">
        <header className={styles.header}>
          <button type="button" className={styles.headerBtn} onClick={onClose}>
            Cancel
          </button>
          <h2 className={styles.headerTitle}>Voice note</h2>
          <span style={{ width: 60 }} aria-hidden />
        </header>
        <div className={styles.body}>
          <p className={styles.hint}>Voice recording is not supported in this browser.</p>
        </div>
      </div>
    );
  }

  if (phase === "review" && audioUrl) {
    return (
      <div className={styles.overlay} role="dialog" aria-modal="true" aria-label="Review voice note">
        <header className={styles.header}>
          <button type="button" className={styles.headerBtn} disabled={saving} onClick={onClose}>
            Cancel
          </button>
          <h2 className={styles.headerTitle}>Review recording</h2>
          <span style={{ width: 60 }} aria-hidden />
        </header>
        <div className={styles.review}>
          <div className={styles.playerWrap}>
            <p className={styles.hint}>Duration: {formatDuration(elapsedMs)}</p>
            <audio controls src={audioUrl} preload="metadata" />
          </div>
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
          </div>
          {error && (
            <p className={styles.error} role="alert">
              {error}
            </p>
          )}
          <div className={styles.reviewActions}>
            <button type="button" className={styles.rerecordBtn} disabled={saving} onClick={discard}>
              Re-record
            </button>
            <button type="button" className={styles.saveBtn} disabled={saving} onClick={save}>
              {saving ? "Saving…" : "Save voice note"}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-label="Record voice note">
      <header className={styles.header}>
        <button
          type="button"
          className={styles.headerBtn}
          disabled={recording}
          onClick={onClose}
        >
          Cancel
        </button>
        <h2 className={styles.headerTitle}>Voice note</h2>
        <span style={{ width: 60 }} aria-hidden />
      </header>

      <div className={styles.body}>
        <div className={styles.timer} aria-live="polite">
          {formatDuration(elapsedMs)}
        </div>
        <div className={styles.waveform} aria-hidden>
          {levels.map((level, i) => (
            <div
              key={i}
              className={styles.bar}
              style={{ height: `${Math.round(level * 100)}%` }}
            />
          ))}
        </div>
        <p className={styles.hint}>
          {recording ? "Recording… tap stop when finished" : "Tap the button to start recording"}
        </p>
        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}
      </div>

      <div className={styles.controls}>
        <button
          type="button"
          className={styles.secondaryBtn}
          aria-label="Discard recording"
          disabled={!recording && elapsedMs === 0}
          onClick={discard}
        >
          <TrashIcon />
        </button>
        <button
          type="button"
          className={`${styles.recordBtn} ${recording ? styles.recordBtnActive : ""}`}
          aria-label={recording ? "Stop recording" : "Start recording"}
          onClick={recording ? stopRecording : startRecording}
        >
          {recording ? <StopIcon /> : <MicIcon />}
        </button>
        <button
          type="button"
          className={styles.secondaryBtn}
          aria-label="Finish recording"
          disabled={!recording}
          onClick={stopRecording}
        >
          <CheckIcon />
        </button>
      </div>
    </div>
  );
}

function MicIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M12 14a3 3 0 0 0 3-3V6a3 3 0 1 0-6 0v5a3 3 0 0 0 3 3z" />
      <path d="M19 11v1a7 7 0 0 1-14 0v-1" />
    </svg>
  );
}

function StopIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <rect x="6" y="6" width="12" height="12" rx="2" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M20 6L9 17l-5-5" />
    </svg>
  );
}
