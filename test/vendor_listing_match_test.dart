import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/album_breakdown.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

Sticker _sticker({
  required String code,
  required String teamCode,
  required int slotNumber,
}) {
  return Sticker(
    code: code,
    teamCode: teamCode,
    teamName: teamCode,
    slotNumber: slotNumber,
    category: 'player',
    group: 'Group',
  );
}

void main() {
  group('needCodesInVendorListing', () {
    const listing = '''
MEX1 - 4 foo
SCO12 - 1 blabla
SCO4 - 1 dfgsdfg
ARG99 - 2 not in need
''';

    final needStickers = [
      _sticker(code: 'MEX3', teamCode: 'MEX', slotNumber: 3),
      _sticker(code: 'MEX1', teamCode: 'MEX', slotNumber: 1),
      _sticker(code: 'SCO12', teamCode: 'SCO', slotNumber: 12),
      _sticker(code: 'ARG17', teamCode: 'ARG', slotNumber: 17),
    ];

    test('returns intersection with need list only', () {
      final matches = needCodesInVendorListing(listing, needStickers);
      expect(matches, ['MEX1', 'SCO12']);
    });

    test('sort order matches formatNeedExport', () {
      final matches = needCodesInVendorListing(listing, needStickers);
      final matchedStickers = [
        for (final s in needStickers)
          if (matches.contains(s.code)) s,
      ];
      final exportOrder = formatNeedExport(matchedStickers).split('\n');
      expect(matches, exportOrder);
    });

    test('excludes need codes not present in listing', () {
      final matches = needCodesInVendorListing(listing, needStickers);
      expect(matches, isNot(contains('MEX3')));
      expect(matches, isNot(contains('ARG17')));
    });

    test('excludes vendor codes not on need list', () {
      final matches = needCodesInVendorListing(listing, needStickers);
      expect(matches, isNot(contains('SCO4')));
      expect(matches, isNot(contains('ARG99')));
    });

    test('empty listing returns empty matches', () {
      expect(needCodesInVendorListing('', needStickers), isEmpty);
    });

    test('empty need list returns empty matches', () {
      expect(needCodesInVendorListing(listing, const []), isEmpty);
    });
  });

  group('needCodesInVendorListing team slot lists', () {
    final needStickers = [
      _sticker(code: 'MEX3', teamCode: 'MEX', slotNumber: 3),
      _sticker(code: 'MEX1', teamCode: 'MEX', slotNumber: 1),
      _sticker(code: 'QAT1', teamCode: 'QAT', slotNumber: 1),
      _sticker(code: 'RSA20', teamCode: 'RSA', slotNumber: 20),
      _sticker(code: 'ARG17', teamCode: 'ARG', slotNumber: 17),
    ];

    test('expands TEAM: 1, 2, 3 with blank lines between teams', () {
      const listing = '''
MEX: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20

RSA: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20

QAT: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
''';
      final matches = needCodesInVendorListing(listing, needStickers);
      expect(matches, ['MEX1', 'MEX3', 'QAT1', 'RSA20']);
      expect(matches, isNot(contains('ARG17')));
    });

    test('accepts compact commas without spaces', () {
      const spaced = 'MEX: 1, 2, 3';
      const compact = 'MEX: 1,2,3';
      expect(
        needCodesInVendorListing(spaced, needStickers),
        needCodesInVendorListing(compact, needStickers),
      );
      expect(needCodesInVendorListing(compact, needStickers), ['MEX1', 'MEX3']);
    });

    test('newlines between teams do not change matches', () {
      const withBreaks = 'MEX: 1, 2, 3\n\n\nQAT: 1';
      const compact = 'MEX: 1, 2, 3 QAT: 1';
      expect(
        needCodesInVendorListing(withBreaks, needStickers),
        needCodesInVendorListing(compact, needStickers),
      );
    });

    test('unions colon lists with glued sticker codes', () {
      const listing = '''
MEX: 1,2,3
SCO12 - 1 blabla
''';
      final need = [
        ...needStickers,
        _sticker(code: 'SCO12', teamCode: 'SCO', slotNumber: 12),
      ];
      expect(needCodesInVendorListing(listing, need), ['MEX1', 'MEX3', 'SCO12']);
    });
  });
}
