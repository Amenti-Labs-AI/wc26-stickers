import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Maps normalized page coordinates (0–1) onto a [viewSize] canvas using [fit],
/// matching how [CameraPreviewCover] / [Image] render the source [imageSize].
Rect mapNormalizedRect({
  required double x,
  required double y,
  required double w,
  required double h,
  required Size imageSize,
  required Size viewSize,
  BoxFit fit = BoxFit.cover,
}) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return Rect.fromLTWH(
      x * viewSize.width,
      y * viewSize.height,
      w * viewSize.width,
      h * viewSize.height,
    );
  }

  final scale = switch (fit) {
    BoxFit.cover => math.max(
        viewSize.width / imageSize.width,
        viewSize.height / imageSize.height,
      ),
    BoxFit.contain => math.min(
        viewSize.width / imageSize.width,
        viewSize.height / imageSize.height,
      ),
    _ => math.max(
        viewSize.width / imageSize.width,
        viewSize.height / imageSize.height,
      ),
  };

  final scaledW = imageSize.width * scale;
  final scaledH = imageSize.height * scale;
  final offsetX = (viewSize.width - scaledW) / 2;
  final offsetY = (viewSize.height - scaledH) / 2;

  return Rect.fromLTWH(
    offsetX + x * imageSize.width * scale,
    offsetY + y * imageSize.height * scale,
    w * imageSize.width * scale,
    h * imageSize.height * scale,
  );
}

/// Preview size from [CameraController] in the same orientation as the widget.
Size cameraPreviewImageSize({
  required Size previewSize,
  required TargetPlatform platform,
}) {
  if (platform == TargetPlatform.android) {
    return Size(previewSize.height, previewSize.width);
  }
  return previewSize;
}

Size? cameraPreviewImageSizeFromController(CameraController controller) {
  final preview = controller.value.previewSize;
  if (preview == null) return null;
  return cameraPreviewImageSize(
    previewSize: Size(preview.width, preview.height),
    platform: defaultTargetPlatform,
  );
}

double _coverScale(Size imageSize, Size viewSize) => math.max(
      viewSize.width / imageSize.width,
      viewSize.height / imageSize.height,
    );

Offset _normToView({
  required double nx,
  required double ny,
  required Size imageSize,
  required Size viewSize,
}) {
  final scale = _coverScale(imageSize, viewSize);
  final offsetX = (viewSize.width - imageSize.width * scale) / 2;
  final offsetY = (viewSize.height - imageSize.height * scale) / 2;
  return Offset(
    offsetX + nx * imageSize.width * scale,
    offsetY + ny * imageSize.height * scale,
  );
}

({double nx, double ny}) _viewToNorm({
  required Offset point,
  required Size imageSize,
  required Size viewSize,
}) {
  final scale = _coverScale(imageSize, viewSize);
  final offsetX = (viewSize.width - imageSize.width * scale) / 2;
  final offsetY = (viewSize.height - imageSize.height * scale) / 2;
  return (
    nx: (point.dx - offsetX) / (imageSize.width * scale),
    ny: (point.dy - offsetY) / (imageSize.height * scale),
  );
}

/// Reference view used to map normalized rects between two image aspect ratios.
Size referenceCoverViewSize(Size imageSize) {
  const refWidth = 1080.0;
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return const Size(refWidth, refWidth);
  }
  return Size(refWidth, refWidth * imageSize.height / imageSize.width);
}

/// Maps a normalized rect from [fromImage] space into [toImage] space when both
/// are BoxFit.cover fitted to the same view.
({double x, double y, double w, double h}) remapNormalizedRectBetweenImages({
  required double x,
  required double y,
  required double w,
  required double h,
  required Size fromImage,
  required Size toImage,
  Size? viewSize,
}) {
  if (fromImage == toImage) return (x: x, y: y, w: w, h: h);

  final view = viewSize ?? referenceCoverViewSize(toImage);
  final topLeft = _normToView(nx: x, ny: y, imageSize: fromImage, viewSize: view);
  final bottomRight = _normToView(
    nx: x + w,
    ny: y + h,
    imageSize: fromImage,
    viewSize: view,
  );
  final mappedTopLeft =
      _viewToNorm(point: topLeft, imageSize: toImage, viewSize: view);
  final mappedBottomRight =
      _viewToNorm(point: bottomRight, imageSize: toImage, viewSize: view);

  return (
    x: mappedTopLeft.nx,
    y: mappedTopLeft.ny,
    w: mappedBottomRight.nx - mappedTopLeft.nx,
    h: mappedBottomRight.ny - mappedTopLeft.ny,
  );
}

/// Full-bleed camera preview using [BoxFit.cover], aligned with overlay mapping.
///
/// [CameraPreview] alone uses [AspectRatio] (letterboxed). Overlays assume cover
/// fill — this widget matches [Image] with [BoxFit.cover] in photo mode.
class CameraCoverPreview extends StatelessWidget {
  const CameraCoverPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final preview = controller.value.previewSize;
    if (preview == null) {
      return CameraPreview(controller);
    }

    final imageSize = cameraPreviewImageSize(
      previewSize: Size(preview.width, preview.height),
      platform: defaultTargetPlatform,
    );

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: imageSize.width,
          height: imageSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
