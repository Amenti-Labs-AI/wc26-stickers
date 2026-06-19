import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/ml/missing_scan_filter.dart';

void main() {
  test('confirmedMissingCodes extracts sorted unique sticker codes', () {
    expect(
      confirmedMissingStickerCodes(['QAT8', 'QAT3', 'bad', 'QAT8']),
      ['QAT3', 'QAT8'],
    );
  });
}
