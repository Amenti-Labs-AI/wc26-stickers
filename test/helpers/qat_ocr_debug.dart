// Debug helper — run via integration test on device.

import 'package:panini_wc26_tracker/ml/ocr_speed.dart';
import 'package:panini_wc26_tracker/ml/page_scan_service.dart';
import 'package:panini_wc26_tracker/ml/template_ocr.dart';

import 'portrait_ocr_fixtures.dart';

Future<void> debugZoomCrop(int page, String code) async {
  final full = await loadTrainPage(page);
  final crop = cropForSlot(full, code);
  final service = PageScanService();
  await service.initialize();
  final lines = await ocrPageTextLines(
    service.matcher.textRecognizer,
    crop,
    speed: OcrSpeed.crop,
  );
  // ignore: avoid_print
  print('=== page_$page zoom $code (${crop.width}x${crop.height}) ===');
  for (final line in lines) {
    // ignore: avoid_print
    print(
      '"${line.text}" norm=${line.normalizedText} '
      '@${line.centerX.toStringAsFixed(3)},${line.centerY.toStringAsFixed(3)}',
    );
  }
}

Future<void> debugQatPageOcr(int page) async {
  final image = await loadTrainHalfPage(page);

  final service = PageScanService();
  await service.initialize();
  final lines = await ocrPageTextLines(
    service.matcher.textRecognizer,
    image,
    speed: OcrSpeed.standard,
  );

  // ignore: avoid_print
  print('=== page_$page OCR (${lines.length} lines) ===');
  for (final line in lines) {
    // ignore: avoid_print
    print(
      '"${line.text}" norm=${line.normalizedText} '
      '@${line.centerX.toStringAsFixed(3)},${line.centerY.toStringAsFixed(3)}',
    );
  }
}
