"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Item, MediaFile } from "@/lib/api-jobs";
import {
  ANNOTATION_PALETTE,
  cloneShapes,
  computeLayout,
  displayToNorm,
  loadImageFromUrl,
  paintShapes,
  type AnnotationTool,
  type PhotoAnnotationShape,
} from "@/lib/photo-annotation";
import { fetchAnnotationDocument, savePhotoAnnotations } from "@/lib/save-photo-annotations";
import { getPhotoMedia, mediaDownloadUrl } from "@/lib/photo-media";
import styles from "./photo-annotation.module.css";

type Props = {
  jobId: string;
  item: Item;
  media: MediaFile[];
  onClose: () => void;
  onSaved: (updatedMedia: MediaFile[]) => void;
};

const MAX_UNDO = 50;

export function PhotoAnnotationEditor({ jobId, item, media, onClose, onSaved }: Props) {
  const { primary, overlay, hasAnnotations } = getPhotoMedia(media);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const imageRef = useRef<HTMLImageElement | null>(null);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [legacyNotice, setLegacyNotice] = useState(false);
  const [tool, setTool] = useState<AnnotationTool>("pen");
  const [color, setColor] = useState<string>(ANNOTATION_PALETTE[0]);
  const [shapes, setShapes] = useState<PhotoAnnotationShape[]>([]);
  const [preview, setPreview] = useState<PhotoAnnotationShape | null>(null);
  const [undoStack, setUndoStack] = useState<PhotoAnnotationShape[][]>([]);
  const [redoStack, setRedoStack] = useState<PhotoAnnotationShape[][]>([]);
  const [dirty, setDirty] = useState(false);
  const [textDialog, setTextDialog] = useState<{ x: number; y: number } | null>(null);

  const penPoints = useRef<number[][]>([]);
  const dragStart = useRef<{ x: number; y: number } | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!primary) {
        setError("Original photo not available");
        setLoading(false);
        return;
      }
      try {
        const img = await loadImageFromUrl(mediaDownloadUrl(primary.id));
        if (cancelled) return;
        imageRef.current = img;

        if (overlay) {
          const doc = await fetchAnnotationDocument(overlay.id);
          if (doc && !cancelled) {
            setShapes(cloneShapes(doc.shapes));
          }
        } else if (hasAnnotations) {
          setLegacyNotice(true);
        }
        setLoading(false);
      } catch {
        if (!cancelled) {
          setError("Could not load photo");
          setLoading(false);
        }
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [primary, overlay, hasAnnotations]);

  const redraw = useCallback(() => {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    const img = imageRef.current;
    if (!canvas || !wrap || !img) return;

    const w = wrap.clientWidth;
    const h = wrap.clientHeight;
    if (w === 0 || h === 0) return;

    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, w, h);

    const layout = computeLayout(img.naturalWidth, img.naturalHeight, w, h);
    ctx.drawImage(img, layout.destLeft, layout.destTop, layout.destWidth, layout.destHeight);
    paintShapes(ctx, shapes, layout, preview ?? undefined);
  }, [shapes, preview]);

  useEffect(() => {
    redraw();
    const ro = new ResizeObserver(redraw);
    if (wrapRef.current) ro.observe(wrapRef.current);
    return () => ro.disconnect();
  }, [redraw]);

  function pushUndo() {
    setUndoStack((s) => [...s.slice(-MAX_UNDO + 1), cloneShapes(shapes)]);
    setRedoStack([]);
  }

  function commitShape(shape: PhotoAnnotationShape) {
    pushUndo();
    setShapes((s) => [...s, shape]);
    setPreview(null);
    setDirty(true);
    penPoints.current = [];
    dragStart.current = null;
  }

  function getLayout() {
    const wrap = wrapRef.current;
    const img = imageRef.current;
    if (!wrap || !img) return null;
    return computeLayout(img.naturalWidth, img.naturalHeight, wrap.clientWidth, wrap.clientHeight);
  }

  function shapeForDrag(
    t: AnnotationTool,
    start: { x: number; y: number },
    end: { x: number; y: number },
  ): PhotoAnnotationShape {
    const type =
      t === "line" ? "line" : t === "arrow" ? "arrow" : t === "ellipse" ? "ellipse" : t === "rectangle" ? "rectangle" : "pen";
    if (t === "ellipse" || t === "rectangle") {
      const left = Math.min(start.x, end.x);
      const top = Math.min(start.y, end.y);
      const width = Math.abs(end.x - start.x);
      const height = Math.abs(end.y - start.y);
      return { type, colorHex: color, rect: [left, top, width, height] };
    }
    return {
      type,
      colorHex: color,
      p1: [start.x, start.y],
      p2: [end.x, end.y],
    };
  }

  function onPointerDown(e: React.PointerEvent) {
    if (tool === "text") return;
    const layout = getLayout();
    if (!layout) return;
    canvasRef.current?.setPointerCapture(e.pointerId);
    const norm = displayToNorm(layout, e.nativeEvent.offsetX, e.nativeEvent.offsetY);

    if (tool === "pen") {
      penPoints.current = [[norm.x, norm.y]];
      setPreview({ type: "pen", colorHex: color, points: [[norm.x, norm.y]] });
    } else {
      dragStart.current = norm;
      setPreview(shapeForDrag(tool, norm, norm));
    }
  }

  function onPointerMove(e: React.PointerEvent) {
    const layout = getLayout();
    if (!layout) return;
    const norm = displayToNorm(layout, e.nativeEvent.offsetX, e.nativeEvent.offsetY);

    if (tool === "pen" && penPoints.current.length > 0) {
      penPoints.current = [...penPoints.current, [norm.x, norm.y]];
      setPreview({ type: "pen", colorHex: color, points: [...penPoints.current] });
      return;
    }

    if (dragStart.current && tool !== "text") {
      setPreview(shapeForDrag(tool, dragStart.current, norm));
    }
  }

  function onPointerUp() {
    const p = preview;
    if (!p) return;

    if (p.type === "pen") {
      if (penPoints.current.length > 0) commitShape(p);
      else setPreview(null);
      return;
    }

    if (p.type === "ellipse" || p.type === "rectangle") {
      const rect = p.rect;
      if (!rect || Math.abs(rect[2]) < 0.005 || Math.abs(rect[3]) < 0.005) {
        setPreview(null);
        return;
      }
    } else if (p.p1 && p.p2) {
      const dx = p.p2[0] - p.p1[0];
      const dy = p.p2[1] - p.p1[1];
      if (dx * dx + dy * dy < 0.00001) {
        setPreview(null);
        return;
      }
    } else {
      setPreview(null);
      return;
    }

    commitShape(p);
  }

  function onCanvasClick(e: React.MouseEvent) {
    if (tool !== "text") return;
    setTextDialog({ x: e.nativeEvent.offsetX, y: e.nativeEvent.offsetY });
  }

  function undo() {
    if (undoStack.length === 0) return;
    setRedoStack((r) => [...r, cloneShapes(shapes)]);
    const prev = undoStack[undoStack.length - 1];
    setUndoStack((s) => s.slice(0, -1));
    setShapes(prev);
    setDirty(true);
    setPreview(null);
  }

  function redo() {
    if (redoStack.length === 0) return;
    setUndoStack((s) => [...s, cloneShapes(shapes)]);
    const next = redoStack[redoStack.length - 1];
    setRedoStack((r) => r.slice(0, -1));
    setShapes(next);
    setDirty(true);
    setPreview(null);
  }

  async function clearAll() {
    if (shapes.length === 0) return;
    if (!confirm("Clear all mark-up? This removes every stroke from this photo.")) return;
    pushUndo();
    setShapes([]);
    setDirty(true);
    setPreview(null);
  }

  async function handleClose() {
    if (!dirty) {
      onClose();
      return;
    }
    if (confirm("Discard changes? Your mark-up has not been saved.")) {
      onClose();
    }
  }

  async function handleSave() {
    setSaving(true);
    setError(null);
    try {
      const updated = await savePhotoAnnotations({
        jobId,
        item,
        media,
        document: { version: 2, shapes: cloneShapes(shapes) },
      });
      onSaved(updated);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save");
    } finally {
      setSaving(false);
    }
  }

  function addTextLabel(text: string) {
    const layout = getLayout();
    if (!layout || !textDialog) return;
    const norm = displayToNorm(layout, textDialog.x, textDialog.y);
    commitShape({ type: "text", colorHex: color, p1: [norm.x, norm.y], text: text.trim() });
    setTextDialog(null);
  }

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (textDialog) return;
      if ((e.metaKey || e.ctrlKey) && e.key === "z" && !e.shiftKey) {
        e.preventDefault();
        undo();
      }
      if ((e.metaKey || e.ctrlKey) && e.key === "z" && e.shiftKey) {
        e.preventDefault();
        redo();
      }
      if (e.key === "Escape") {
        e.preventDefault();
        handleClose();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  if (loading) {
    return (
      <div className={styles.annotationEditor}>
        <div className={styles.annotationLoading}>Loading photo…</div>
      </div>
    );
  }

  if (error && !primary) {
    return (
      <div className={styles.annotationEditor}>
        <div className={styles.annotationHeader}>
          <h2 className={styles.annotationTitle}>Annotate</h2>
          <button type="button" className={styles.annotationClose} onClick={onClose}>
            ×
          </button>
        </div>
        <div className={styles.annotationLoading}>{error}</div>
      </div>
    );
  }

  return (
    <div className={styles.annotationEditor}>
      <header className={styles.annotationHeader}>
        <button type="button" className={styles.annotationClose} onClick={handleClose} aria-label="Close">
          ×
        </button>
        <h2 className={styles.annotationTitle}>Annotate</h2>
        <div className={styles.annotationHeaderActions}>
          {error && <span className={styles.error}>{error}</span>}
          <button type="button" className={styles.annotationSave} disabled={saving} onClick={handleSave}>
            {saving ? "Saving…" : "Save"}
          </button>
        </div>
      </header>

      <div ref={wrapRef} className={styles.annotationCanvasWrap}>
        {legacyNotice && (
          <p className={styles.annotationNotice}>
            Mark-up was flattened on sync; redraw or save to replace.
          </p>
        )}
        <canvas
          ref={canvasRef}
          className={styles.annotationCanvas}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerLeave={onPointerUp}
          onClick={onCanvasClick}
        />
      </div>

      <footer className={styles.annotationToolbar}>
        <div className={styles.annotationTools}>
          <ToolBtn label="Pen" icon="✎" selected={tool === "pen"} onClick={() => setTool("pen")} />
          <ToolBtn label="Line" icon="—" selected={tool === "line"} onClick={() => setTool("line")} />
          <ToolBtn label="Arrow" icon="→" selected={tool === "arrow"} onClick={() => setTool("arrow")} />
          <ToolBtn label="Circle" icon="○" selected={tool === "ellipse"} onClick={() => setTool("ellipse")} />
          <ToolBtn label="Box" icon="□" selected={tool === "rectangle"} onClick={() => setTool("rectangle")} />
          <ToolBtn label="Text" icon="T" selected={tool === "text"} onClick={() => setTool("text")} />
          <button
            type="button"
            className={styles.annotationIconBtn}
            disabled={undoStack.length === 0}
            onClick={undo}
            title="Undo"
          >
            ↩
          </button>
          <button
            type="button"
            className={styles.annotationIconBtn}
            disabled={redoStack.length === 0}
            onClick={redo}
            title="Redo"
          >
            ↪
          </button>
          <button type="button" className={styles.annotationIconBtn} onClick={clearAll} title="Clear all">
            🗑
          </button>
        </div>
        <div className={styles.annotationColors}>
          <span className={styles.annotationColorsLabel}>Color</span>
          {ANNOTATION_PALETTE.map((c) => (
            <button
              key={c}
              type="button"
              className={`${styles.annotationSwatch} ${color === c ? styles.annotationSwatchSelected : ""}`}
              style={{ background: c, borderColor: c === "#FFFFFF" ? "#d1d5db" : c }}
              onClick={() => setColor(c)}
              aria-label={`Color ${c}`}
            />
          ))}
        </div>
      </footer>

      {textDialog && (
        <TextLabelDialog
          onCancel={() => setTextDialog(null)}
          onAdd={(text) => {
            if (text.trim()) addTextLabel(text);
            else setTextDialog(null);
          }}
        />
      )}
    </div>
  );
}

function ToolBtn({
  label,
  icon,
  selected,
  onClick,
}: {
  label: string;
  icon: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={`${styles.annotationTool} ${selected ? styles.annotationToolSelected : ""}`}
      onClick={onClick}
    >
      <span className={styles.annotationToolIcon}>{icon}</span>
      {label}
    </button>
  );
}

function TextLabelDialog({ onCancel, onAdd }: { onCancel: () => void; onAdd: (text: string) => void }) {
  const [value, setValue] = useState("");
  return (
    <div className={styles.textDialogBackdrop} onClick={onCancel}>
      <div className={styles.textDialog} onClick={(e) => e.stopPropagation()}>
        <h3>Add label</h3>
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          maxLength={80}
          placeholder="e.g. Leak here"
          autoFocus
          onKeyDown={(e) => {
            if (e.key === "Enter") onAdd(value);
            if (e.key === "Escape") onCancel();
          }}
        />
        <div className={styles.textDialogActions}>
          <button type="button" onClick={onCancel}>
            Cancel
          </button>
          <button type="button" className={styles.textDialogPrimary} onClick={() => onAdd(value)}>
            Add
          </button>
        </div>
      </div>
    </div>
  );
}
