import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'ocr_speed.dart';
import 'ocr_text_line.dart';

const _standardMinDimension = 1200;
const _standardMaxDimension = 1920;

/// Live camera frames are already downscaled — never upscale for OCR.
const _liveMinDimension = 0;
const _liveMaxDimension = 640;
const _liveJpegQuality = 72;

const _cropMinDimension = 1600;
const _cropMaxDimension = 1920;
const _cropAltMinDimension = 1920;

Future<void> _ocrSerial = Future<void>.value();
File? _ocrTempFile;

Future<T> runSerialOcr<T>(Future<T> Function() action) async {
  final previous = _ocrSerial;
  final done = Completer<void>();
  _ocrSerial = done.future;
  await previous;
  try {
    return await action();
  } finally {
    if (!done.isCompleted) done.complete();
  }
}

(int minDimension, int maxDimension) _ocrDimensions(OcrSpeed speed) =>
    switch (speed) {
      OcrSpeed.live => (_liveMinDimension, _liveMaxDimension),
      OcrSpeed.crop => (_cropMinDimension, _cropMaxDimension),
      OcrSpeed.standard => (_standardMinDimension, _standardMaxDimension),
    };

img.Image _resizeToMinDimension(img.Image image, int minDimension) {
  if (minDimension <= 0) return image;
  final maxDim = math.max(image.width, image.height);
  if (maxDim >= minDimension) return image;
  final scale = minDimension / maxDim;
  return img.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
  );
}

img.Image _prepareImageForOcr(
  img.Image image, {
  required int minDimension,
  required int maxDimension,
}) {
  var prepared = _resizeToMinDimension(image, minDimension);
  final maxDim = math.max(prepared.width, prepared.height);
  if (maxDim <= maxDimension) return prepared;
  final scale = maxDimension / maxDim;
  return img.copyResize(
    prepared,
    width: math.max(1, (prepared.width * scale).round()),
    height: math.max(1, (prepared.height * scale).round()),
  );
}

List<OcrTextLine> _mergeOcrLines(List<OcrTextLine> primary, List<OcrTextLine> extra) {
  final merged = [...primary];
  for (final line in extra) {
    final duplicate = merged.any(
      (existing) =>
          existing.normalizedText == line.normalizedText &&
          (existing.centerX - line.centerX).abs() < 0.04 &&
          (existing.centerY - line.centerY).abs() < 0.04,
    );
    if (!duplicate) merged.add(line);
  }
  return merged;
}

Future<String?> ocrHeaderText(
  TextRecognizer recognizer,
  img.Image header, {
  OcrSpeed speed = OcrSpeed.standard,
}) async {
  if (header.width <= 0 || header.height <= 0) return null;
  final dims = _ocrDimensions(speed);
  final result = await _processImage(
    recognizer,
    _prepareImageForOcr(
      header,
      minDimension: dims.$1,
      maxDimension: dims.$2,
    ),
  );
  return result?.text;
}

Future<String?> ocrCropText(
  TextRecognizer recognizer,
  img.Image crop, {
  OcrSpeed speed = OcrSpeed.standard,
}) async {
  if (crop.width <= 0 || crop.height <= 0) return null;
  final dims = _ocrDimensions(speed);
  final prepared = _prepareImageForOcr(
    crop,
    minDimension: dims.$1,
    maxDimension: dims.$2,
  );
  final result = await _processImage(recognizer, prepared);
  return result?.text;
}

Future<List<OcrTextLine>> ocrPageTextLines(
  TextRecognizer recognizer,
  img.Image page, {
  OcrSpeed speed = OcrSpeed.standard,
}) async {
  if (page.width <= 0 || page.height <= 0) return const [];

  final dims = _ocrDimensions(speed);
  var lines = await _ocrLinesFromPrepared(
    recognizer,
    _prepareImageForOcr(
      page,
      minDimension: dims.$1,
      maxDimension: dims.$2,
    ),
    speed: speed,
  );

  if (speed == OcrSpeed.crop) {
    final alt = _prepareImageForOcr(
      page,
      minDimension: _cropAltMinDimension,
      maxDimension: _cropMaxDimension,
    );
    lines = _mergeOcrLines(
      lines,
      await _ocrLinesFromPrepared(recognizer, alt, speed: speed),
    );
  } else if (speed == OcrSpeed.standard) {
    final sourceMax = math.max(page.width, page.height);
    if (sourceMax < 900) {
      final alt = _prepareImageForOcr(
        page,
        minDimension: _cropAltMinDimension,
        maxDimension: _cropMaxDimension,
      );
      lines = _mergeOcrLines(
        lines,
        await _ocrLinesFromPrepared(recognizer, alt, speed: speed),
      );
    }
  }

  return lines;
}

Future<List<OcrTextLine>> _ocrLinesFromPrepared(
  TextRecognizer recognizer,
  img.Image ocrPage, {
  OcrSpeed speed = OcrSpeed.standard,
}) async {
  final result = await _processImage(recognizer, ocrPage, speed: speed);
  if (result == null) return const [];

  final lines = <OcrTextLine>[];
  final pageW = ocrPage.width.toDouble();
  final pageH = ocrPage.height.toDouble();
  for (final block in result.blocks) {
    for (final line in block.lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final box = line.boundingBox;
      if (box.width <= 0 || box.height <= 0) continue;
      lines.add(
        OcrTextLine.fromNums(
          text: text,
          x: box.left / pageW,
          y: box.top / pageH,
          w: box.width / pageW,
          h: box.height / pageH,
        ),
      );
    }
  }
  return lines;
}

Future<RecognizedText?> processOcrImage(
  TextRecognizer recognizer,
  InputImage input,
) =>
    recognizer.processImage(input);

Future<RecognizedText?> _processImage(
  TextRecognizer recognizer,
  img.Image image, {
  OcrSpeed speed = OcrSpeed.standard,
}) async {
  if (image.width <= 0 || image.height <= 0) return null;

  final jpegQuality = speed == OcrSpeed.live ? _liveJpegQuality : 82;

  return runSerialOcr(() async {
    Uint8List bytes;
    try {
      bytes = Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
    } catch (_) {
      return null;
    }

    try {
      _ocrTempFile ??=
          File('${(await getTemporaryDirectory()).path}/panini_ocr_live.jpg');
      await _ocrTempFile!.writeAsBytes(bytes, flush: true);
      return await processOcrImage(
        recognizer,
        InputImage.fromFilePath(_ocrTempFile!.path),
      );
    } catch (_) {
      return null;
    }
  });
}
