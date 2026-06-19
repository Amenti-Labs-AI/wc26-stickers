import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:panini_wc26_tracker/ml/ocr_speed.dart';
import 'package:panini_wc26_tracker/ml/ocr_text_line.dart';
import 'package:panini_wc26_tracker/ml/portrait_ocr_scanner.dart';
import 'package:panini_wc26_tracker/ml/portrait_text_matcher.dart';

import 'helpers/portrait_ocr_fixtures.dart';

/// Host-side matcher tests (no ML Kit). Real OCR runs in integration_test/.
void main() {
  group('Portrait OCR strategy — matcher path', () {
    test('pairs stacked MEX labels into expected page_8 codes', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: _syntheticPage8Lines(),
        knownTeamCodes: {'MEX'},
      );
      final codes = matches.map((m) => m.stickerCode).toSet();
      expect(codes, page8ExpectedMissing);
    });

    test('pairs stacked MEX labels into expected page_9 codes', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: _syntheticPage9Lines(),
        knownTeamCodes: {'MEX'},
      );
      final codes = matches.map((m) => m.stickerCode).toSet();
      expect(codes, page9ExpectedMissing);
    });

    test('pairs stacked QAT labels into expected page_20 codes', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: _syntheticPage20Lines(),
        knownTeamCodes: {'QAT'},
      );
      final codes = matches.map((m) => m.stickerCode).toSet();
      expect(codes, page20ExpectedMissing);
    });

    test('pairs horizontal FWC4 landscape label', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: _syntheticFwc4Horizontal(),
        knownTeamCodes: {'FWC'},
      );
      final codes = matches.map((m) => m.stickerCode).toSet();
      expect(codes, contains('FWC4'));
    });

    test('speed selection picks crop for small images', () {
      expect(
        PortraitOcrScanner.speedForImage(img.Image(width: 400, height: 300)),
        OcrSpeed.crop,
      );
      expect(
        PortraitOcrScanner.speedForImage(img.Image(width: 800, height: 600)),
        OcrSpeed.standard,
      );
    });
  });
}

List<OcrTextLine> _syntheticPage8Lines() => [
      ..._stackedLabel('MEX', '4', 0.735, 0.14),
      ..._stackedLabel('MEX', '5', 0.06, 0.252),
      ..._stackedLabel('MEX', '8', 0.735, 0.252),
      ..._stackedLabel('MEX', '9', 0.06, 0.424),
      ..._stackedLabel('MEX', '10', 0.285, 0.424),
    ];

List<OcrTextLine> _syntheticPage9Lines() => [
      ..._stackedLabel('MEX', '11', 0.51, 0.424),
      ..._stackedLabel('MEX', '13', 0.06, 0.596),
      ..._stackedLabel('MEX', '17', 0.06, 0.768),
      ..._stackedLabel('MEX', '20', 0.735, 0.768),
    ];

List<OcrTextLine> _syntheticPage20Lines() => [
      ..._stackedLabel('QAT', '3', 0.51, 0.08),
      ..._stackedLabel('QAT', '8', 0.735, 0.08),
      ..._stackedLabel('QAT', '9', 0.06, 0.252),
      ..._stackedLabel('QAT', '10', 0.285, 0.252),
    ];

List<OcrTextLine> _syntheticFwc4Horizontal() => [
      const OcrTextLine(text: 'FWC', x: 0.52, y: 0.24, w: 0.05, h: 0.02),
      const OcrTextLine(text: '4', x: 0.58, y: 0.235, w: 0.02, h: 0.02),
    ];

List<OcrTextLine> _stackedLabel(String team, String number, double x, double y) {
  return [
    OcrTextLine.fromNums(text: team, x: x, y: y, w: 0.06, h: 0.02),
    OcrTextLine.fromNums(
      text: number,
      x: x + 0.01,
      y: y + 0.022,
      w: 0.04,
      h: 0.02,
    ),
  ];
}
