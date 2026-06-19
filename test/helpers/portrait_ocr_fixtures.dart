import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:panini_wc26_tracker/features/scan_page/scan_page_session.dart';
import 'package:panini_wc26_tracker/ml/ocr_speed.dart';
import 'package:panini_wc26_tracker/ml/page_scan_service.dart';
import 'package:panini_wc26_tracker/ml/ocr_text_line.dart';
import 'package:panini_wc26_tracker/ml/portrait_ocr_scanner.dart';
import 'package:panini_wc26_tracker/ml/template_ocr.dart';

// MEX
const mexPage8Asset = 'assets/test_fixtures/mex_page_8.jpg';
const mexPage9Asset = 'assets/test_fixtures/mex_page_9.jpg';
const mexTeamCode = 'MEX';
const page8ExpectedMissing = {'MEX4', 'MEX5', 'MEX8', 'MEX9', 'MEX10'};
const page9ExpectedMissing = {'MEX11', 'MEX13', 'MEX17', 'MEX20'};

// QAT
const qatPage20Asset = 'assets/test_fixtures/qat_page_20.jpg';
const qatPage21Asset = 'assets/test_fixtures/qat_page_21.jpg';
const qatTeamCode = 'QAT';
const page20ExpectedMissing = {'QAT3', 'QAT8', 'QAT9', 'QAT10'};
const page21ExpectedMissing = {'QAT11', 'QAT14', 'QAT15', 'QAT19'};

// FWC intro (page_1)
const fwcPage1Asset = 'assets/test_fixtures/fwc_page_1.jpg';
const fwc4ZoomAsset = 'assets/test_fixtures/fwc4_zoom_crop.jpg';
const fwcTeamCode = 'FWC';
/// Full-page OCR reliably reads portrait foil labels; landscape FWC4 needs zoom.
const page1FwcExpectedMissing = {'FWC1', 'FWC2'};

/// Photo-calibrated norm crops for zoom OCR (not template coords).
const _mexZoomCrops = <String, ({double x, double y, double w, double h})>{
  'MEX4': (x: 0.34, y: 0.24, w: 0.30, h: 0.32),
  'MEX5': (x: 0.54, y: 0.24, w: 0.30, h: 0.32),
  'MEX11': (x: 0.02, y: 0.02, w: 0.38, h: 0.32),
  'MEX13': (x: 0.58, y: 0.02, w: 0.40, h: 0.32),
};

const _qatZoomCrops = <String, ({double x, double y, double w, double h})>{
  // Photo-calibrated on device; QAT3 uses orphan "3" + team lock.
  'QAT3': (x: 0.00, y: 0.35, w: 0.32, h: 0.22),
  'QAT8': (x: 0.22, y: 0.52, w: 0.32, h: 0.22),
  'QAT11': (x: 0.06, y: 0.02, w: 0.26, h: 0.22),
  'QAT14': (x: 0.04, y: 0.30, w: 0.26, h: 0.24),
};

const _fwcZoomCrops = <String, ({double x, double y, double w, double h})>{
  'FWC1': (x: 0.58, y: 0.04, w: 0.38, h: 0.22),
  // FWC4 landscape — row-2 left slot (fwc_intro.json x=0.06 y=0.252).
  'FWC4': (x: 0.04, y: 0.24, w: 0.28, h: 0.14),
};

Future<ScanPageSession> createOcrSession() async {
  final service = PageScanService();
  final session = ScanPageSession(service);
  await session.ensureReady();
  return session;
}

Future<PortraitOcrScanner> createMexOcrScanner() async {
  final service = PageScanService();
  await service.initialize();
  return PortraitOcrScanner(
    recognizer: service.matcher.textRecognizer,
    templates: service.templates,
  );
}

Future<img.Image> loadTrainPage(int page) => loadTrainHalfPage(page);

Future<img.Image> loadTrainHalfPage(int page) async {
  for (final asset in _assetCandidatesForPage(page)) {
    try {
      final data = await rootBundle.load(asset);
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded != null) return decoded;
    } catch (_) {}
  }
  throw TestFailure('missing test fixture for page $page');
}

List<String> _assetCandidatesForPage(int page) => [
      if (page == 1) fwcPage1Asset,
      'assets/test_fixtures/qat_page_$page.jpg',
      'assets/test_fixtures/mex_page_$page.jpg',
    ];

Future<img.Image> loadMexHalfPage(int page) async {
  if (page != 8 && page != 9) {
    return loadTrainHalfPage(page);
  }
  final asset = page == 8 ? mexPage8Asset : mexPage9Asset;
  final data = await rootBundle.load(asset);
  final decoded = img.decodeImage(data.buffer.asUint8List());
  expect(decoded, isNotNull, reason: 'decode $asset');
  return decoded!;
}

Future<img.Image> loadFwcPage1() => loadTrainHalfPage(1);

Future<img.Image> loadFwc4ZoomCrop() async {
  final data = await rootBundle.load(fwc4ZoomAsset);
  final decoded = img.decodeImage(data.buffer.asUint8List());
  expect(decoded, isNotNull, reason: 'decode $fwc4ZoomAsset');
  return decoded!;
}

img.Image cropForSlot(img.Image page, String code) {
  final region = _mexZoomCrops[code] ??
      _qatZoomCrops[code] ??
      _fwcZoomCrops[code];
  expect(region, isNotNull, reason: 'no zoom crop for $code');
  return cropNorm(
    page,
    x: region!.x,
    y: region.y,
    w: region.w,
    h: region.h,
  );
}

img.Image cropForMexSlot(img.Image page, String code) => cropForSlot(page, code);

img.Image cropNorm(
  img.Image page, {
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  return img.copyCrop(
    page,
    x: (x * page.width).round().clamp(0, page.width - 1),
    y: (y * page.height).round().clamp(0, page.height - 1),
    width: (w * page.width).round().clamp(1, page.width),
    height: (h * page.height).round().clamp(1, page.height),
  );
}

img.Image toGrayscale(img.Image page) {
  final gray = img.Image(width: page.width, height: page.height);
  for (var y = 0; y < page.height; y++) {
    for (var x = 0; x < page.width; x++) {
      final p = page.getPixel(x, y);
      final lum = img.getLuminance(p).round().clamp(0, 255);
      gray.setPixelRgb(x, y, lum, lum, lum);
    }
  }
  return gray;
}

Future<List<OcrTextLine>> ocrLinesForPage(
  img.Image page, {
  OcrSpeed speed = OcrSpeed.standard,
}) async {
  final service = PageScanService();
  await service.initialize();
  return ocrPageTextLines(
    service.matcher.textRecognizer,
    page,
    speed: speed,
  );
}

Future<PortraitOcrScanResult> scanStill(
  ScanPageSession session,
  img.Image page, {
  OcrSpeed? speed,
}) {
  return session.scanStillPage(page, speed: speed ?? OcrSpeed.standard);
}

void expectExactCodes(PortraitOcrScanResult result, Set<String> expected) {
  expect(
    result.missingCodes,
    expected,
    reason: 'OCR debug: ${result.debug}',
  );
}

void expectContainsCodes(
  PortraitOcrScanResult result,
  Set<String> required, {
  Set<String> forbidden = const {},
}) {
  expect(
    result.missingCodes,
    containsAll(required),
    reason: 'OCR debug: ${result.debug}',
  );
  for (final code in forbidden) {
    expect(result.missingCodes, isNot(contains(code)));
  }
}
