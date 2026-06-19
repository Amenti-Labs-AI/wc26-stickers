import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/ml/ocr_text_line.dart';
import 'package:panini_wc26_tracker/ml/portrait_text_matcher.dart';

void main() {
  group('PortraitTextMatcher', () {
    final matcher = PortraitTextMatcher();

    test('pairs team line above number line', () {
      const team = OcrTextLine(text: 'CUW', x: 0.10, y: 0.40, w: 0.04, h: 0.012);
      const number = OcrTextLine(text: '5', x: 0.11, y: 0.415, w: 0.02, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [team, number],
        knownTeamCodes: {'CUW', 'BRA'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.stickerCode, 'CUW5');
      expect(matches.first.teamCode, 'CUW');
      expect(matches.first.slotNumber, 5);
      expect(matches.first.overlayW, greaterThan(matches.first.readW));
      expect(matches.first.overlayH, greaterThan(matches.first.readH));
      expect(matches.first.overlayW, lessThan(0.25));
      expect(matches.first.overlayH, lessThan(0.40));
    });

    test('scales overlay from OCR read cluster', () {
      const t1 = OcrTextLine(text: 'CUW', x: 0.10, y: 0.40, w: 0.04, h: 0.012);
      const n1 = OcrTextLine(text: '5', x: 0.11, y: 0.415, w: 0.02, h: 0.012);
      const t2 = OcrTextLine(text: 'CUW', x: 0.30, y: 0.55, w: 0.08, h: 0.020);
      const n2 = OcrTextLine(text: '7', x: 0.31, y: 0.575, w: 0.03, h: 0.018);

      final matches = matcher.matchStackedTeamNumber(
        lines: [t1, n1, t2, n2],
        knownTeamCodes: {'CUW'},
      );

      expect(matches, hasLength(2));
      for (final m in matches) {
        expect(m.overlayW, closeTo(m.readW / 0.46, 0.05));
        expect(m.overlayH, closeTo(m.readH / 0.22, 0.08));
      }
    });

    test('anchors overlay top above label cluster', () {
      const team = OcrTextLine(text: 'CUW', x: 0.20, y: 0.40, w: 0.04, h: 0.012);
      const number = OcrTextLine(text: '5', x: 0.21, y: 0.415, w: 0.02, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [team, number],
        knownTeamCodes: {'CUW'},
      );

      expect(matches, hasLength(1));
      final m = matches.first;
      final read = team.mergeWith(number);
      expect(m.overlayY, lessThan(read.y));
      expect(m.overlayX + m.overlayW / 2, closeTo(read.centerX, 0.02));
    });

    test('matches single-line catalog codes in body', () {
      const line = OcrTextLine(text: 'BRA 14', x: 0.2, y: 0.5, w: 0.06, h: 0.015);

      final matches = matcher.matchStackedTeamNumber(
        lines: [line],
        knownTeamCodes: {'BRA'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.stickerCode, 'BRA14');
    });

    test('pairs truncated FW with number as FWC on intro page', () {
      const team = OcrTextLine(text: 'FW', x: 0.10, y: 0.72, w: 0.04, h: 0.012);
      const number = OcrTextLine(text: '14', x: 0.11, y: 0.735, w: 0.03, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [team, number],
        knownTeamCodes: {'FWC'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.stickerCode, 'FWC14');
    });

    test('matches bottom-half FWC stacked labels', () {
      const team = OcrTextLine(text: 'FWC', x: 0.10, y: 0.72, w: 0.04, h: 0.012);
      const number = OcrTextLine(text: '14', x: 0.11, y: 0.735, w: 0.03, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [team, number],
        knownTeamCodes: {'FWC'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.stickerCode, 'FWC14');
      expect(matches.first.overlayY, lessThan(0.72));
    });

    test('matches bottom-half FWC single-line labels', () {
      const line = OcrTextLine(text: 'FWC14', x: 0.10, y: 0.88, w: 0.06, h: 0.015);

      final matches = matcher.matchStackedTeamNumber(
        lines: [line],
        knownTeamCodes: {'FWC'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.stickerCode, 'FWC14');
      expect(matches.first.overlayY, lessThan(0.88));
    });

    test('ignores single-line codes for unknown teams', () {
      const line = OcrTextLine(text: 'BRA 14', x: 0.2, y: 0.5, w: 0.06, h: 0.015);

      final matches = matcher.matchStackedTeamNumber(
        lines: [line],
        knownTeamCodes: {'CUW'},
      );

      expect(matches, isEmpty);
    });

    test('ignores header team codes without a body number', () {
      const header = OcrTextLine(text: 'CUW', x: 0.4, y: 0.05, w: 0.05, h: 0.02);
      const bodyTeam = OcrTextLine(text: 'CUW', x: 0.1, y: 0.45, w: 0.04, h: 0.012);
      const bodyNum = OcrTextLine(text: '3', x: 0.11, y: 0.465, w: 0.02, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [header, bodyTeam, bodyNum],
        knownTeamCodes: {'CUW'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.slotNumber, 3);
    });

    test('filters wrong team when filterTeamCode set', () {
      const team = OcrTextLine(text: 'HAI', x: 0.1, y: 0.45, w: 0.04, h: 0.012);
      const number = OcrTextLine(text: '1', x: 0.11, y: 0.465, w: 0.02, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [team, number],
        filterTeamCode: 'CUW',
        knownTeamCodes: {'CUW', 'HAI'},
      );

      expect(matches, isEmpty);
    });

    test('does not cross-pair team with neighbor slot number on same row', () {
      const mex8Team = OcrTextLine(text: 'MEX', x: 0.43, y: 0.65, w: 0.05, h: 0.02);
      const eight = OcrTextLine(text: '8', x: 0.43, y: 0.68, w: 0.03, h: 0.02);
      const mex9Team = OcrTextLine(text: 'MEX', x: 0.63, y: 0.66, w: 0.05, h: 0.02);

      final matches = matcher.matchStackedTeamNumber(
        lines: [mex8Team, eight, mex9Team],
        knownTeamCodes: {'MEX'},
        filterTeamCode: 'MEX',
      );

      expect(matches.map((m) => m.stickerCode).toSet(), {'MEX8'});
      expect(
        matcher.findUnpairedTeamLines(
          lines: [mex8Team, eight, mex9Team],
          matches: matches,
          knownTeamCodes: {'MEX'},
          filterTeamCode: 'MEX',
        ),
        hasLength(1),
      );
    });

    test('pairs team and number with wider vertical gap', () {
      const team = OcrTextLine(text: 'BRA', x: 0.10, y: 0.40, w: 0.04, h: 0.012);
      const number = OcrTextLine(text: '14', x: 0.11, y: 0.488, w: 0.03, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [team, number],
        knownTeamCodes: {'BRA'},
      );

      expect(matches, hasLength(1));
      expect(matches.first.stickerCode, 'BRA14');
    });

    test('infers dominant team from matches', () {
      const t1 = OcrTextLine(text: 'CUW', x: 0.1, y: 0.4, w: 0.04, h: 0.012);
      const n1 = OcrTextLine(text: '1', x: 0.11, y: 0.415, w: 0.02, h: 0.012);
      const t2 = OcrTextLine(text: 'CUW', x: 0.3, y: 0.4, w: 0.04, h: 0.012);
      const n2 = OcrTextLine(text: '2', x: 0.31, y: 0.415, w: 0.02, h: 0.012);

      final matches = matcher.matchStackedTeamNumber(
        lines: [t1, n1, t2, n2],
        knownTeamCodes: {'CUW', 'BRA'},
      );

      expect(matcher.inferTeamFromMatches(matches), 'CUW');
    });
  });
}
