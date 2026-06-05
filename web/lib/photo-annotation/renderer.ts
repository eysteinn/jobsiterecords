import type { PhotoAnnotationShape } from "./types";
import { STROKE_WIDTH_NORM, colorForHex } from "./types";
import type { ImageLayoutMetrics } from "./layout";
import { normRect, normToDisplay } from "./layout";

export function strokeWidthPx(imageWidth: number): number {
  return Math.max(2, imageWidth * STROKE_WIDTH_NORM);
}

export function paintShapes(
  ctx: CanvasRenderingContext2D,
  shapes: PhotoAnnotationShape[],
  layout: ImageLayoutMetrics,
  preview?: PhotoAnnotationShape,
): void {
  const all = preview ? [...shapes, preview] : shapes;
  for (const shape of all) {
    paintShape(ctx, shape, layout);
  }
}

function paintShape(
  ctx: CanvasRenderingContext2D,
  shape: PhotoAnnotationShape,
  layout: ImageLayoutMetrics,
): void {
  const color = colorForHex(shape.colorHex);
  const strokeW = strokeWidthPx(layout.imageWidth);
  ctx.strokeStyle = color;
  ctx.lineWidth = strokeW;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";

  switch (shape.type) {
    case "pen":
      paintPen(ctx, shape.points ?? [], layout, strokeW);
      break;
    case "line":
      if (shape.p1 && shape.p2) {
        const a = normToDisplay(layout, shape.p1[0], shape.p1[1]);
        const b = normToDisplay(layout, shape.p2[0], shape.p2[1]);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.stroke();
      }
      break;
    case "arrow":
      if (shape.p1 && shape.p2) {
        const a = normToDisplay(layout, shape.p1[0], shape.p1[1]);
        const b = normToDisplay(layout, shape.p2[0], shape.p2[1]);
        paintArrow(ctx, a.x, a.y, b.x, b.y, strokeW);
      }
      break;
    case "ellipse":
      if (shape.rect) {
        const r = normRect(layout, shape.rect);
        ctx.beginPath();
        ctx.ellipse(
          r.x + r.width / 2,
          r.y + r.height / 2,
          Math.abs(r.width / 2),
          Math.abs(r.height / 2),
          0,
          0,
          Math.PI * 2,
        );
        ctx.stroke();
      }
      break;
    case "rectangle":
      if (shape.rect) {
        const r = normRect(layout, shape.rect);
        ctx.strokeRect(r.x, r.y, r.width, r.height);
      }
      break;
    case "text":
      if (shape.p1 && shape.text) {
        paintTextLabel(ctx, layout, shape.p1, shape.text, color);
      }
      break;
  }
}

function paintPen(
  ctx: CanvasRenderingContext2D,
  points: number[][],
  layout: ImageLayoutMetrics,
  strokeW: number,
): void {
  if (points.length === 0) return;
  if (points.length === 1) {
    const p = normToDisplay(layout, points[0][0], points[0][1]);
    ctx.beginPath();
    ctx.arc(p.x, p.y, strokeW / 2, 0, Math.PI * 2);
    ctx.stroke();
    return;
  }
  ctx.beginPath();
  const first = normToDisplay(layout, points[0][0], points[0][1]);
  ctx.moveTo(first.x, first.y);
  for (let i = 1; i < points.length; i++) {
    const p = normToDisplay(layout, points[i][0], points[i][1]);
    ctx.lineTo(p.x, p.y);
  }
  ctx.stroke();
}

function paintArrow(
  ctx: CanvasRenderingContext2D,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  strokeW: number,
): void {
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.stroke();

  const angle = Math.atan2(y2 - y1, x2 - x1);
  const headLength = strokeW * 4;
  const headAngle = Math.PI / 7;

  const p1x = x2 - headLength * Math.cos(angle - headAngle);
  const p1y = y2 - headLength * Math.sin(angle - headAngle);
  const p2x = x2 - headLength * Math.cos(angle + headAngle);
  const p2y = y2 - headLength * Math.sin(angle + headAngle);

  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(p1x, p1y);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(p2x, p2y);
  ctx.stroke();
}

function paintTextLabel(
  ctx: CanvasRenderingContext2D,
  layout: ImageLayoutMetrics,
  anchor: number[],
  label: string,
  color: string,
): void {
  const fontSize = Math.max(14, layout.imageWidth * 0.028);
  ctx.font = `600 ${fontSize}px system-ui, sans-serif`;
  ctx.textBaseline = "top";

  const topLeft = normToDisplay(layout, anchor[0], anchor[1]);
  const metrics = ctx.measureText(label);
  const padding = fontSize * 0.2;
  const bgW = metrics.width + padding * 2;
  const bgH = fontSize * 1.2 + padding * 2;

  ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
  const radius = fontSize * 0.25;
  roundRect(ctx, topLeft.x, topLeft.y, bgW, bgH, radius);
  ctx.fill();

  ctx.fillStyle = color === "#FFFFFF" ? "#FFFFFF" : color;
  ctx.fillText(label, topLeft.x + padding, topLeft.y + padding);
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

export async function renderJpeg(
  image: CanvasImageSource,
  imageWidth: number,
  imageHeight: number,
  shapes: PhotoAnnotationShape[],
  quality = 0.9,
): Promise<Blob> {
  const canvas = document.createElement("canvas");
  canvas.width = imageWidth;
  canvas.height = imageHeight;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Could not create canvas");

  ctx.drawImage(image, 0, 0, imageWidth, imageHeight);
  const layout = {
    imageWidth,
    imageHeight,
    canvasWidth: imageWidth,
    canvasHeight: imageHeight,
    destLeft: 0,
    destTop: 0,
    destWidth: imageWidth,
    destHeight: imageHeight,
  };
  paintShapes(ctx, shapes, layout);

  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("JPEG encode failed"))),
      "image/jpeg",
      quality,
    );
  });
}

export async function loadImageFromUrl(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Could not load image"));
    img.src = url;
  });
}
