import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/sticker_code_parser.dart';
import 'package:panini_wc26_tracker/ml/ocr_text_line.dart';
import 'package:panini_wc26_tracker/ml/portrait_text_matcher.dart';
import 'package:panini_wc26_tracker/ml/team_code_ocr_aliases.dart';

void main() {
  group('team_code_ocr_aliases', () {
    test('maps stylized QAT misreads', () {
      const known = {'QAT', 'MEX'};
      expect(resolveOcrTeamToken('OAT', known), 'QAT');
      expect(resolveOcrTeamToken('AT', known), 'QAT');
      expect(resolveOcrTeamToken('0AT', known), 'QAT');
    });

    test('StickerCodeParser parses OAT as QAT', () {
      expect(StickerCodeParser.parse('OAT 8'), 'QAT8');
      expect(StickerCodeParser.parse('OAT8'), 'QAT8');
      expect(StickerCodeParser.parse('OAT 8 TAREK SALMAN'), 'QAT8');
    });

    test('matcher pairs OAT stacked label', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: [
          const OcrTextLine(text: 'OAT', x: 0.45, y: 0.55, w: 0.05, h: 0.02),
          const OcrTextLine(text: '8', x: 0.46, y: 0.575, w: 0.03, h: 0.02),
        ],
        knownTeamCodes: {'QAT'},
        filterTeamCode: 'QAT',
      );
      expect(matches.map((m) => m.stickerCode).toSet(), {'QAT8'});
    });

    test('maps stylized IRQ misreads', () {
      const known = {'IRQ', 'MEX'};
      expect(resolveOcrTeamToken('IRO', known), 'IRQ');
      expect(resolveOcrTeamToken('IR0', known), 'IRQ');
      expect(resolveOcrTeamToken('IR', known), 'IRQ');
    });

    test('StickerCodeParser parses IRO as IRQ', () {
      expect(StickerCodeParser.parse('IRO 8'), 'IRQ8');
      expect(StickerCodeParser.parse('IRO8'), 'IRQ8');
    });

    test('matcher pairs IRO stacked label', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: [
          const OcrTextLine(text: 'IRO', x: 0.45, y: 0.55, w: 0.05, h: 0.02),
          const OcrTextLine(text: '8', x: 0.46, y: 0.575, w: 0.03, h: 0.02),
        ],
        knownTeamCodes: {'IRQ'},
        filterTeamCode: 'IRQ',
      );
      expect(matches.map((m) => m.stickerCode).toSet(), {'IRQ8'});
    });

    test('matcher pairs IR0 stacked label', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: [
          const OcrTextLine(text: 'IR0', x: 0.45, y: 0.55, w: 0.05, h: 0.02),
          const OcrTextLine(text: '8', x: 0.46, y: 0.575, w: 0.03, h: 0.02),
        ],
        knownTeamCodes: {'IRQ'},
        filterTeamCode: 'IRQ',
      );
      expect(matches.map((m) => m.stickerCode).toSet(), {'IRQ8'});
    });
  });
}
