import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/ml/scan_engine.dart';

void main() {
  test('default scan engine is portrait OCR', () {
    expect(ScanEngine.fromStorage(null), ScanEngine.portraitOcr);
    expect(ScanEngine.fromStorage('unknown'), ScanEngine.portraitOcr);
  });

  test('legacy storage keys map to portrait OCR', () {
    expect(ScanEngine.fromStorage('slotDetection'), ScanEngine.portraitOcr);
    expect(ScanEngine.fromStorage('portraitOcr'), ScanEngine.portraitOcr);
  });

  test('portrait OCR metadata is present', () {
    expect(ScanEngine.portraitOcr.displayName, isNotEmpty);
    expect(ScanEngine.portraitOcr.subtitle, isNotEmpty);
    expect(ScanEngine.portraitOcr.detailBullets, isNotEmpty);
  });
}
