import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/sticker_code_parser.dart';

void main() {
  group('StickerCodeParser', () {
    test('parses team player codes', () {
      expect(StickerCodeParser.parse('BRA 14'), 'BRA14');
      expect(StickerCodeParser.parse('CAN3'), 'CAN3');
      expect(StickerCodeParser.parse('Printed: USA 7'), 'USA7');
    });

    test('parses FWC codes', () {
      expect(StickerCodeParser.parse('FWC 0'), 'FWC0');
      expect(StickerCodeParser.parse('fwc 12'), 'FWC12');
    });

    test('parseAll finds multiple codes', () {
      final codes = StickerCodeParser.parseAll('Need BRA14, MEX3 and FWC 1');
      expect(codes, containsAll(['BRA14', 'MEX3', 'FWC1']));
    });

    test('returns null for garbage', () {
      expect(StickerCodeParser.parse('hello world'), isNull);
    });

    test('parseWithTeamHint ignores FW branding on team pages', () {
      expect(StickerCodeParser.parseWithTeamHint('FW 14', 'HAI'), 'HAI14');
      expect(StickerCodeParser.parseWithTeamHint('FWC FIFA 7', 'HAI'), 'HAI7');
      expect(StickerCodeParser.parseWithTeamHint('14', 'HAI'), 'HAI14');
    });

    test('parse skips bare FW misreads', () {
      expect(StickerCodeParser.parse('FW 14'), isNull);
      expect(StickerCodeParser.parse('FWC 3'), 'FWC3');
    });
  });
}
