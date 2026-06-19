import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/ml/ocr_label_rescue.dart';
import 'package:panini_wc26_tracker/ml/ocr_text_line.dart';
import 'package:panini_wc26_tracker/ml/portrait_text_matcher.dart';

void main() {
  group('ocr_label_rescue', () {
    test('labelBandForTeamLine centers on team label', () {
      const team = OcrTextLine(text: 'MEX', x: 0.60, y: 0.66, w: 0.05, h: 0.02);
      final band = labelBandForTeamLine(team);
      expect(band.w, 0.20);
      expect(band.h, 0.07);
      expect(team.centerX, greaterThanOrEqualTo(band.x));
      expect(team.centerX, lessThanOrEqualTo(band.x + band.w));
    });

    test('remapCropLinesToPage maps crop coords to page coords', () {
      const cropLine = OcrTextLine(text: '9', x: 0.50, y: 0.60, w: 0.10, h: 0.05);
      final remapped = remapCropLinesToPage(
        [cropLine],
        cropX: 0.55,
        cropY: 0.65,
        cropW: 0.20,
        cropH: 0.07,
      );
      expect(remapped, hasLength(1));
      expect(remapped.first.text, '9');
      expect(remapped.first.x, closeTo(0.55 + 0.50 * 0.20, 0.001));
      expect(remapped.first.y, closeTo(0.65 + 0.60 * 0.07, 0.001));
    });

    test('rescued digit pairs with unpaired MEX9 team line', () {
      const team = OcrTextLine(text: 'MEX', x: 0.60, y: 0.66, w: 0.05, h: 0.02);
      const number = OcrTextLine(text: '9', x: 0.61, y: 0.685, w: 0.03, h: 0.02);

      final matcher = PortraitTextMatcher();
      final initial = matcher.matchStackedTeamNumber(
        lines: [team],
        knownTeamCodes: {'MEX'},
        filterTeamCode: 'MEX',
      );
      expect(initial, isEmpty);

      final unpaired = matcher.findUnpairedTeamLines(
        lines: [team],
        matches: initial,
        knownTeamCodes: {'MEX'},
        filterTeamCode: 'MEX',
      );
      expect(unpaired, hasLength(1));

      final merged = mergeOcrLineLists([team], [number]);
      final matches = matcher.matchStackedTeamNumber(
        lines: merged,
        knownTeamCodes: {'MEX'},
        filterTeamCode: 'MEX',
      );
      expect(matches.map((m) => m.stickerCode).toSet(), {'MEX9'});
    });
  });
}
