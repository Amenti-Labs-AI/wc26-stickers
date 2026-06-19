import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/camera_frame_codec.dart';
import 'ocr_text_line.dart';
import 'template_ocr_mobile.dart' show processOcrImage, runSerialOcr;

/// Upright analysis size after applying [payload] sensor rotation.
(int width, int height) orientedAnalysisDimensions(CameraFramePayload payload) {
  final swap = payload.sensorOrientation == 90 ||
      payload.sensorOrientation == 270;
  return swap ? (payload.height, payload.width) : (payload.width, payload.height);
}

InputImageRotation rotationFromSensor(int sensorOrientation) {
  return switch (sensorOrientation) {
    90 => InputImageRotation.rotation90deg,
    180 => InputImageRotation.rotation180deg,
    270 => InputImageRotation.rotation270deg,
    _ => InputImageRotation.rotation0deg,
  };
}

/// OCR directly from a live camera frame without RGB decode (Android NV21 / iOS BGRA).
///
/// Returns `null` when the platform/format is unsupported so callers can fall back
/// to [decodeCameraFramePayload] + JPEG OCR.
Future<List<OcrTextLine>?> ocrLiveCameraLines(
  TextRecognizer recognizer,
  CameraFramePayload payload,
) async {
  if (payload.planes.isEmpty) return null;

  try {
    if (Platform.isAndroid && payload.formatName == 'nv21') {
      return _ocrAndroidNv21(recognizer, payload);
    }
    if (Platform.isIOS && payload.formatName == 'bgra8888') {
      return _ocrIosBgra(recognizer, payload);
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<List<OcrTextLine>> _ocrAndroidNv21(
  TextRecognizer recognizer,
  CameraFramePayload payload,
) async {
  final bytes = _nv21Bytes(payload);
  if (bytes == null) return const [];

  final result = await runSerialOcr(
    () => processOcrImage(
      recognizer,
      InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(payload.width.toDouble(), payload.height.toDouble()),
          rotation: rotationFromSensor(payload.sensorOrientation),
          format: InputImageFormat.nv21,
          bytesPerRow: payload.bytesPerRows.first,
        ),
      ),
    ),
  );
  if (result == null) return const [];

  final (pageW, pageH) = orientedAnalysisDimensions(payload);
  return linesFromRecognizedText(
    result,
    pageWidth: pageW.toDouble(),
    pageHeight: pageH.toDouble(),
  );
}

Future<List<OcrTextLine>> _ocrIosBgra(
  TextRecognizer recognizer,
  CameraFramePayload payload,
) async {
  final result = await runSerialOcr(
    () => processOcrImage(
      recognizer,
      InputImage.fromBytes(
        bytes: payload.planes.first,
        metadata: InputImageMetadata(
          size: Size(payload.width.toDouble(), payload.height.toDouble()),
          rotation: rotationFromSensor(payload.sensorOrientation),
          format: InputImageFormat.bgra8888,
          bytesPerRow: payload.bytesPerRows.first,
        ),
      ),
    ),
  );
  if (result == null) return const [];

  final (pageW, pageH) = orientedAnalysisDimensions(payload);
  return linesFromRecognizedText(
    result,
    pageWidth: pageW.toDouble(),
    pageHeight: pageH.toDouble(),
  );
}

Uint8List? _nv21Bytes(CameraFramePayload payload) {
  if (payload.planes.length == 1) return payload.planes.first;
  if (payload.planes.length < 2) return null;
  final y = payload.planes[0];
  final vu = payload.planes[1];
  final merged = Uint8List(y.length + vu.length);
  merged.setRange(0, y.length, y);
  merged.setRange(y.length, merged.length, vu);
  return merged;
}

List<OcrTextLine> linesFromRecognizedText(
  RecognizedText result, {
  required double pageWidth,
  required double pageHeight,
}) {
  if (pageWidth <= 0 || pageHeight <= 0) return const [];

  final lines = <OcrTextLine>[];
  for (final block in result.blocks) {
    for (final line in block.lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final box = line.boundingBox;
      if (box.width <= 0 || box.height <= 0) continue;
      lines.add(
        OcrTextLine.fromNums(
          text: text,
          x: box.left / pageWidth,
          y: box.top / pageHeight,
          w: box.width / pageWidth,
          h: box.height / pageHeight,
        ),
      );
    }
  }
  return lines;
}
