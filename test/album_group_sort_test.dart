import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/album_group.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

Sticker _sticker({
  required String teamCode,
  required String teamName,
  required String group,
  int? albumPage,
  int slotNumber = 1,
}) =>
    Sticker(
      code: '$teamCode$slotNumber',
      teamCode: teamCode,
      teamName: teamName,
      slotNumber: slotNumber,
      category: 'player',
      group: group,
      albumPage: albumPage,
    );

void main() {
  group('compareStickersByAlbumOrder', () {
    test('orders FWC, then groups, then Coca-Cola', () {
      final fwc = _sticker(
        teamCode: 'FWC',
        teamName: 'FIFA World Cup',
        group: 'FWC',
      );
      final mex = _sticker(
        teamCode: 'MEX',
        teamName: 'Mexico',
        group: 'Group A',
        albumPage: 8,
      );
      final cc = _sticker(
        teamCode: 'CC',
        teamName: 'Coca-Cola',
        group: 'Coca-Cola',
      );

      final ordered = [cc, mex, fwc]
        ..sort(compareStickersByAlbumOrder);
      expect(ordered.map((s) => s.teamCode), ['FWC', 'MEX', 'CC']);
    });

    test('orders teams within a group by album page', () {
      final mex = _sticker(
        teamCode: 'MEX',
        teamName: 'Mexico',
        group: 'Group A',
        albumPage: 8,
      );
      final rsa = _sticker(
        teamCode: 'RSA',
        teamName: 'South Africa',
        group: 'Group A',
        albumPage: 10,
      );
      final kor = _sticker(
        teamCode: 'KOR',
        teamName: 'Korea Republic',
        group: 'Group A',
        albumPage: 12,
      );

      final ordered = [kor, mex, rsa]..sort(compareStickersByAlbumOrder);
      expect(ordered.map((s) => s.teamCode), ['MEX', 'RSA', 'KOR']);
    });
  });

  group('compareStickersByTeamName', () {
    test('orders by section title alphabetically', () {
      final mex = _sticker(
        teamCode: 'MEX',
        teamName: 'Mexico',
        group: 'Group A',
        albumPage: 8,
      );
      final bra = _sticker(
        teamCode: 'BRA',
        teamName: 'Brazil',
        group: 'Group C',
        albumPage: 24,
      );
      final fwc = _sticker(
        teamCode: 'FWC',
        teamName: 'FIFA World Cup',
        group: 'FWC',
      );

      final ordered = [mex, fwc, bra]..sort(compareStickersByTeamName);
      expect(
        ordered.map((s) => s.teamSectionTitle),
        ['Brazil', 'FIFA World Cup', 'Mexico'],
      );
    });
  });

  group('albumPageNumber', () {
    test('returns the earliest page in a team spread', () {
      final stickers = [
        _sticker(
          teamCode: 'MEX',
          teamName: 'Mexico',
          group: 'Group A',
          albumPage: 8,
        ),
        _sticker(
          teamCode: 'MEX',
          teamName: 'Mexico',
          group: 'Group A',
          albumPage: 9,
          slotNumber: 11,
        ),
      ];
      expect(albumPageNumber(stickers), 8);
    });

    test('returns null when pages are unknown', () {
      final stickers = [
        _sticker(
          teamCode: 'CC',
          teamName: 'Coca-Cola',
          group: 'Coca-Cola',
        ),
      ];
      expect(albumPageNumber(stickers), isNull);
    });
  });
}
