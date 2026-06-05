import type { PhotoAnnotationDocument, PhotoAnnotationShape } from "./types";
import { DOCUMENT_VERSION } from "./types";

export function emptyDocument(): PhotoAnnotationDocument {
  return { version: DOCUMENT_VERSION, shapes: [] };
}

export function encodeDocument(doc: PhotoAnnotationDocument): string {
  return JSON.stringify({
    version: doc.version,
    shapes: doc.shapes.map(shapeToJson),
  });
}

export function decodeDocument(source: string): PhotoAnnotationDocument {
  try {
    const parsed = JSON.parse(source) as { shapes?: unknown };
    if (!parsed || !Array.isArray(parsed.shapes)) {
      return emptyDocument();
    }
    return {
      version: DOCUMENT_VERSION,
      shapes: parsed.shapes
        .filter((s): s is Record<string, unknown> => typeof s === "object" && s !== null)
        .map(shapeFromJson),
    };
  } catch {
    return emptyDocument();
  }
}

export function cloneShapes(shapes: PhotoAnnotationShape[]): PhotoAnnotationShape[] {
  return shapes.map((s) => ({
    type: s.type,
    colorHex: s.colorHex,
    points: s.points?.map((p) => [p[0], p[1]]),
    p1: s.p1 ? [s.p1[0], s.p1[1]] : undefined,
    p2: s.p2 ? [s.p2[0], s.p2[1]] : undefined,
    rect: s.rect ? [s.rect[0], s.rect[1], s.rect[2], s.rect[3]] : undefined,
    text: s.text,
  }));
}

function shapeToJson(shape: PhotoAnnotationShape): Record<string, unknown> {
  const out: Record<string, unknown> = {
    type: shape.type,
    color: shape.colorHex,
  };
  if (shape.points && shape.points.length > 0) out.points = shape.points;
  if (shape.p1) out.p1 = shape.p1;
  if (shape.p2) out.p2 = shape.p2;
  if (shape.rect) out.rect = shape.rect;
  if (shape.text) out.text = shape.text;
  return out;
}

function shapeFromJson(json: Record<string, unknown>): PhotoAnnotationShape {
  return {
    type: String(json.type ?? "pen"),
    colorHex: String(json.color ?? "#EF4444"),
    points: readPointList(json.points),
    p1: readPoint(json.p1),
    p2: readPoint(json.p2),
    rect: readRect(json.rect),
    text: typeof json.text === "string" ? json.text : undefined,
  };
}

function readPoint(raw: unknown): number[] | undefined {
  if (!Array.isArray(raw) || raw.length < 2) return undefined;
  return [Number(raw[0]), Number(raw[1])];
}

function readPointList(raw: unknown): number[][] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((p): p is unknown[] => Array.isArray(p) && p.length >= 2)
    .map((p) => [Number(p[0]), Number(p[1])]);
}

function readRect(raw: unknown): number[] | undefined {
  if (!Array.isArray(raw) || raw.length < 4) return undefined;
  return [Number(raw[0]), Number(raw[1]), Number(raw[2]), Number(raw[3])];
}
