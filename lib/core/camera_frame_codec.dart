import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Long edge cap for live scan analysis (portrait detect + OCR). Normalized
/// overlay coords are resolution-independent.
const liveScanMaxDimension = 1280;

/// Copy of one camera frame — safe to pass to a background isolate.
class CameraFramePayload {
  const CameraFramePayload({
    required this.width,
    required this.height,
    required this.sensorOrientation,
    required this.formatName,
    required this.planes,
    required this.bytesPerRows,
    this.maxAnalysisEdge = liveScanMaxDimension,
  });

  final int width;
  final int height;
  final int sensorOrientation;
  final String formatName;
  final List<Uint8List> planes;
  final List<int> bytesPerRows;
  final int maxAnalysisEdge;

  /// Fast byte copy while the platform buffer is still valid.
  static CameraFramePayload? capture(
    CameraImage frame,
    CameraDescription camera, {
    int maxAnalysisEdge = liveScanMaxDimension,
  }) {
    if (frame.planes.isEmpty) return null;
    try {
      return CameraFramePayload(
        width: frame.width,
        height: frame.height,
        sensorOrientation: camera.sensorOrientation,
        formatName: frame.format.group.name,
        planes: frame.planes.map((p) => Uint8List.fromList(p.bytes)).toList(),
        bytesPerRows: frame.planes.map((p) => p.bytesPerRow).toList(),
        maxAnalysisEdge: maxAnalysisEdge,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Decode + orient + downscale off the UI thread ([compute] entry point).
img.Image? decodeCameraFramePayload(CameraFramePayload payload) {
  final base = _decodePayload(payload);
  if (base == null) return null;
  final oriented = _orientForPortrait(base, payload.sensorOrientation);
  return _downscale(oriented, payload.maxAnalysisEdge);
}

img.Image? _decodePayload(CameraFramePayload payload) {
  return switch (payload.formatName) {
    'bgra8888' => _bgra8888FromPayload(payload),
    'yuv420' => _yuv420FromPayload(payload),
    'nv21' => _nv21FromPayload(payload),
    _ => null,
  };
}

int _decodeStepForTarget(int width, int height, int maxEdge) {
  final maxDim = math.max(width, height);
  if (maxDim <= maxEdge) return 1;
  return math.max(1, (maxDim / maxEdge).ceil());
}

img.Image _downscale(img.Image image, int maxEdge) {
  final maxDim = math.max(image.width, image.height);
  if (maxDim <= maxEdge) return image;
  final scale = maxEdge / maxDim;
  return img.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
  );
}

img.Image _orientForPortrait(img.Image image, int sensorOrientation) {
  return switch (sensorOrientation) {
    90 => img.copyRotate(image, angle: 90),
    180 => img.copyRotate(image, angle: 180),
    270 => img.copyRotate(image, angle: 270),
    _ => image,
  };
}

img.Image? _bgra8888FromPayload(CameraFramePayload payload) {
  if (payload.planes.isEmpty) return null;
  final plane = payload.planes.first;
  final step = _decodeStepForTarget(
    payload.width,
    payload.height,
    payload.maxAnalysisEdge,
  );
  final out = img.Image(
    width: math.max(1, (payload.width / step).ceil()),
    height: math.max(1, (payload.height / step).ceil()),
  );
  final rowStride = payload.bytesPerRows.first;
  for (var y = 0; y < payload.height; y += step) {
    for (var x = 0; x < payload.width; x += step) {
      final i = y * rowStride + x * 4;
      if (i + 3 >= plane.length) return null;
      final b = plane[i];
      final g = plane[i + 1];
      final r = plane[i + 2];
      out.setPixelRgb(x ~/ step, y ~/ step, r, g, b);
    }
  }
  return out;
}

img.Image? _yuv420FromPayload(CameraFramePayload payload) {
  if (payload.planes.length < 3) return null;
  final yPlane = payload.planes[0];
  final uPlane = payload.planes[1];
  final vPlane = payload.planes[2];
  final yRow = payload.bytesPerRows[0];
  final uRow = payload.bytesPerRows[1];
  final out = img.Image(width: payload.width, height: payload.height);

  for (var y = 0; y < payload.height; y++) {
    for (var x = 0; x < payload.width; x++) {
      final yIndex = y * yRow + x;
      final uvRow = (y ~/ 2) * uRow;
      final uvCol = x ~/ 2;
      final u = uPlane[uvRow + uvCol];
      final v = vPlane[uvRow + uvCol];
      final yVal = yPlane[yIndex];
      final rgb = _yuvToRgb(yVal, u, v);
      out.setPixelRgb(x, y, rgb.$1, rgb.$2, rgb.$3);
    }
  }
  return out;
}

img.Image? _nv21FromPayload(CameraFramePayload payload) {
  if (payload.planes.isEmpty) return null;
  if (payload.planes.length >= 2) {
    return _nv21FromSplitPlanes(payload);
  }
  return _nv21FromSinglePlane(payload);
}

img.Image? _nv21FromSinglePlane(CameraFramePayload payload) {
  final plane = payload.planes.first;
  final bytes = plane;
  final width = payload.width;
  final height = payload.height;
  final rowStride = payload.bytesPerRows.first;
  final ySize = rowStride * height;
  final step = _decodeStepForTarget(width, height, payload.maxAnalysisEdge);
  final out = img.Image(
    width: math.max(1, (width / step).ceil()),
    height: math.max(1, (height / step).ceil()),
  );

  for (var y = 0; y < height; y += step) {
    for (var x = 0; x < width; x += step) {
      final yIndex = y * rowStride + x;
      if (yIndex >= bytes.length) return null;
      final uvIndex = ySize + (y ~/ 2) * rowStride + (x ~/ 2) * 2;
      if (uvIndex + 1 >= bytes.length) return null;
      final rgb = _yuvToRgb(
        bytes[yIndex],
        bytes[uvIndex + 1],
        bytes[uvIndex],
      );
      out.setPixelRgb(x ~/ step, y ~/ step, rgb.$1, rgb.$2, rgb.$3);
    }
  }
  return out;
}

img.Image? _nv21FromSplitPlanes(CameraFramePayload payload) {
  final yPlane = payload.planes[0];
  final vuPlane = payload.planes[1];
  final yRow = payload.bytesPerRows[0];
  final vuRow = payload.bytesPerRows[1];
  final step =
      _decodeStepForTarget(payload.width, payload.height, payload.maxAnalysisEdge);
  final out = img.Image(
    width: math.max(1, (payload.width / step).ceil()),
    height: math.max(1, (payload.height / step).ceil()),
  );

  for (var y = 0; y < payload.height; y += step) {
    for (var x = 0; x < payload.width; x += step) {
      final yIndex = y * yRow + x;
      final uvIndex = (y ~/ 2) * vuRow + (x ~/ 2) * 2;
      if (yIndex >= yPlane.length || uvIndex + 1 >= vuPlane.length) {
        return null;
      }
      final rgb = _yuvToRgb(
        yPlane[yIndex],
        vuPlane[uvIndex + 1],
        vuPlane[uvIndex],
      );
      out.setPixelRgb(x ~/ step, y ~/ step, rgb.$1, rgb.$2, rgb.$3);
    }
  }
  return out;
}

(int, int, int) _yuvToRgb(int y, int u, int v) {
  final c = y - 16;
  final d = u - 128;
  final e = v - 128;
  var r = (298 * c + 409 * e + 128) >> 8;
  var g = (298 * c - 100 * d - 208 * e + 128) >> 8;
  var b = (298 * c + 516 * d + 128) >> 8;
  r = r.clamp(0, 255);
  g = g.clamp(0, 255);
  b = b.clamp(0, 255);
  return (r, g, b);
}
