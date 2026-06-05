export type AnnotationTool = "pen" | "line" | "arrow" | "ellipse" | "rectangle" | "text";

export type PhotoAnnotationShape = {
  type: string;
  colorHex: string;
  points?: number[][];
  p1?: number[];
  p2?: number[];
  rect?: number[];
  text?: string;
};

export type PhotoAnnotationDocument = {
  version: number;
  shapes: PhotoAnnotationShape[];
};

export const STROKE_WIDTH_NORM = 0.0035;
export const DOCUMENT_VERSION = 2;

export const ANNOTATION_PALETTE = [
  "#EF4444",
  "#EAB308",
  "#FFFFFF",
  "#111827",
  "#22C55E",
] as const;

export function colorForHex(hex: string): string {
  const cleaned = hex.replace("#", "");
  const parsed = parseInt(cleaned, 16);
  if (Number.isNaN(parsed)) return "#EF4444";
  return `#${cleaned.padStart(6, "0")}`;
}

export function hexForColor(hex: string): string {
  return hex.startsWith("#") ? hex.toUpperCase() : `#${hex.toUpperCase()}`;
}
