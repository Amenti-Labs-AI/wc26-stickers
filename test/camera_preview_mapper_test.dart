import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/features/scan_page/camera_preview_mapper.dart';

void main() {
  group('mapNormalizedRect', () {
    test('maps normalized box with cover fit', () {
      const imageSize = Size(640, 480);
      const viewSize = Size(360, 640);
      final rect = mapNormalizedRect(
        x: 0.5,
        y: 0.5,
        w: 0.2,
        h: 0.2,
        imageSize: imageSize,
        viewSize: viewSize,
        fit: BoxFit.cover,
      );
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(viewSize.width));
      expect(rect.bottom, lessThanOrEqualTo(viewSize.height));
    });

    test('cover fit maps corners of image to cropped view', () {
      const imageSize = Size(720, 1280);
      const viewSize = Size(360, 640);
      final full = mapNormalizedRect(
        x: 0,
        y: 0,
        w: 1,
        h: 1,
        imageSize: imageSize,
        viewSize: viewSize,
        fit: BoxFit.cover,
      );
      expect(full.left, closeTo(0, 0.5));
      expect(full.top, closeTo(0, 0.5));
      expect(full.width, closeTo(viewSize.width, 0.5));
      expect(full.height, closeTo(viewSize.height, 0.5));
    });

    test('falls back to view size when image size is zero', () {
      final rect = mapNormalizedRect(
        x: 0.1,
        y: 0.2,
        w: 0.3,
        h: 0.4,
        imageSize: Size.zero,
        viewSize: const Size(400, 800),
      );
      expect(rect, const Rect.fromLTWH(40, 160, 120, 320));
    });
  });

  group('cameraPreviewImageSize', () {
    test('swaps dimensions on Android', () {
      final size = cameraPreviewImageSize(
        previewSize: const Size(1280, 720),
        platform: TargetPlatform.android,
      );
      expect(size, const Size(720, 1280));
    });

    test('keeps dimensions on iOS', () {
      final size = cameraPreviewImageSize(
        previewSize: const Size(1280, 720),
        platform: TargetPlatform.iOS,
      );
      expect(size, const Size(1280, 720));
    });
  });

  group('remapNormalizedRectBetweenImages', () {
    test('identity when source and target share aspect ratio', () {
      const imageSize = Size(720, 1280);
      final mapped = remapNormalizedRectBetweenImages(
        x: 0.1,
        y: 0.2,
        w: 0.25,
        h: 0.3,
        fromImage: imageSize,
        toImage: imageSize,
      );
      expect(mapped.x, closeTo(0.1, 0.001));
      expect(mapped.y, closeTo(0.2, 0.001));
      expect(mapped.w, closeTo(0.25, 0.001));
      expect(mapped.h, closeTo(0.3, 0.001));
    });

    test('maps center point across different aspect ratios', () {
      const analysis = Size(480, 640);
      const preview = Size(720, 1280);
      const view = Size(360, 640);

      final analysisCenter = mapNormalizedRect(
        x: 0.4,
        y: 0.5,
        w: 0.2,
        h: 0.2,
        imageSize: analysis,
        viewSize: view,
        fit: BoxFit.cover,
      );
      final remapped = remapNormalizedRectBetweenImages(
        x: 0.4,
        y: 0.5,
        w: 0.2,
        h: 0.2,
        fromImage: analysis,
        toImage: preview,
        viewSize: view,
      );
      final previewRect = mapNormalizedRect(
        x: remapped.x,
        y: remapped.y,
        w: remapped.w,
        h: remapped.h,
        imageSize: preview,
        viewSize: view,
        fit: BoxFit.cover,
      );

      expect(previewRect.center.dx, closeTo(analysisCenter.center.dx, 1.5));
      expect(previewRect.center.dy, closeTo(analysisCenter.center.dy, 1.5));
    });
  });

  group('preview vs stream aspect alignment', () {
    test('same-aspect preview and stream map normalized point identically', () {
      const streamSize = Size(720, 1280);
      const previewSize = Size(720, 1280);
      const viewSize = Size(360, 640);

      final fromStream = mapNormalizedRect(
        x: 0.06,
        y: 0.40,
        w: 0.205,
        h: 0.152,
        imageSize: streamSize,
        viewSize: viewSize,
        fit: BoxFit.cover,
      );
      final fromPreview = mapNormalizedRect(
        x: 0.06,
        y: 0.40,
        w: 0.205,
        h: 0.152,
        imageSize: previewSize,
        viewSize: viewSize,
        fit: BoxFit.cover,
      );

      expect(fromPreview.left, closeTo(fromStream.left, 0.5));
      expect(fromPreview.top, closeTo(fromStream.top, 0.5));
      expect(fromPreview.width, closeTo(fromStream.width, 0.5));
      expect(fromPreview.height, closeTo(fromStream.height, 0.5));
    });
  });
}
