export type ImageLayoutMetrics = {
  imageWidth: number;
  imageHeight: number;
  canvasWidth: number;
  canvasHeight: number;
  destLeft: number;
  destTop: number;
  destWidth: number;
  destHeight: number;
};

export function computeLayout(
  imageWidth: number,
  imageHeight: number,
  canvasWidth: number,
  canvasHeight: number,
): ImageLayoutMetrics {
  const imageAspect = imageWidth / imageHeight;
  const canvasAspect = canvasWidth / canvasHeight;
  let destWidth: number;
  let destHeight: number;
  let destLeft: number;
  let destTop: number;

  if (imageAspect > canvasAspect) {
    destWidth = canvasWidth;
    destHeight = canvasWidth / imageAspect;
    destLeft = 0;
    destTop = (canvasHeight - destHeight) / 2;
  } else {
    destHeight = canvasHeight;
    destWidth = canvasHeight * imageAspect;
    destTop = 0;
    destLeft = (canvasWidth - destWidth) / 2;
  }

  return {
    imageWidth,
    imageHeight,
    canvasWidth,
    canvasHeight,
    destLeft,
    destTop,
    destWidth,
    destHeight,
  };
}

export function normToDisplay(
  layout: ImageLayoutMetrics,
  nx: number,
  ny: number,
): { x: number; y: number } {
  return {
    x: layout.destLeft + nx * layout.destWidth,
    y: layout.destTop + ny * layout.destHeight,
  };
}

export function displayToNorm(
  layout: ImageLayoutMetrics,
  x: number,
  y: number,
): { x: number; y: number } {
  if (layout.destWidth <= 0 || layout.destHeight <= 0) {
    return { x: 0, y: 0 };
  }
  return {
    x: Math.min(1, Math.max(0, (x - layout.destLeft) / layout.destWidth)),
    y: Math.min(1, Math.max(0, (y - layout.destTop) / layout.destHeight)),
  };
}

export function normRect(
  layout: ImageLayoutMetrics,
  rect: number[],
): { x: number; y: number; width: number; height: number } {
  const topLeft = normToDisplay(layout, rect[0], rect[1]);
  const bottomRight = normToDisplay(layout, rect[0] + rect[2], rect[1] + rect[3]);
  return {
    x: topLeft.x,
    y: topLeft.y,
    width: bottomRight.x - topLeft.x,
    height: bottomRight.y - topLeft.y,
  };
}
