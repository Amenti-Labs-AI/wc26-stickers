import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/sticker_search_query.dart';

TextEditingValue _format(String oldText, String newText) {
  const formatter = TeamCodeSearchFormatter(maxLength: 3);
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(text: newText),
  );
}

void main() {
  group('TeamCodeSearchFormatter', () {
    test('caps at maxLength on paste into empty field', () {
      expect(_format('', 'mex4').text, 'MEX');
    });

    test('rollover replaces full field with newly typed char', () {
      expect(_format('BRA', 'BRAM').text, 'M');
    });

    test('rollover accepts overflow paste after full field', () {
      expect(_format('BRA', 'BRAMEX').text, 'MEX');
    });

    test('normal typing up to maxLength', () {
      expect(_format('BR', 'BRA').text, 'BRA');
    });
  });

  group('StickerSearchQuery', () {
    test('empty input is none', () {
      expect(StickerSearchQuery.parse('').kind, StickerSearchKind.none);
      expect(StickerSearchQuery.parse('   ').kind, StickerSearchKind.none);
      expect(StickerSearchQuery.parse(null).kind, StickerSearchKind.none);
    });

    test('team code only', () {
      final q = StickerSearchQuery.parse('bra');
      expect(q.kind, StickerSearchKind.teamCode);
      expect(q.teamCode, 'BRA');
    });

    test('exact sticker code compact', () {
      final q = StickerSearchQuery.parse('BRA14');
      expect(q.kind, StickerSearchKind.exactCode);
      expect(q.code, 'BRA14');
    });

    test('exact sticker code with space', () {
      final q = StickerSearchQuery.parse('BRA 14');
      expect(q.kind, StickerSearchKind.exactCode);
      expect(q.code, 'BRA14');
    });

    test('FWC and CC codes', () {
      expect(StickerSearchQuery.parse('FWC0').code, 'FWC0');
      expect(StickerSearchQuery.parse('CC3').code, 'CC3');
    });

    test('player names and partial text return none', () {
      expect(StickerSearchQuery.parse('Messi').kind, StickerSearchKind.none);
      expect(StickerSearchQuery.parse('Brazil').kind, StickerSearchKind.none);
      expect(StickerSearchQuery.parse('BR').kind, StickerSearchKind.none);
    });
  });
}
