import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/album_group.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

void main() {
  group('albumGroupKindForCode', () {
    test('national team codes', () {
      expect(albumGroupKindForCode('MEX'), AlbumGroupKind.nationalTeam);
      expect(albumGroupKindForCode('bra'), AlbumGroupKind.nationalTeam);
      expect(isNationalTeamCode('USA'), isTrue);
    });

    test('FWC and CC are album sections', () {
      expect(albumGroupKindForCode('FWC'), AlbumGroupKind.fwc);
      expect(albumGroupKindForCode('CC'), AlbumGroupKind.cocaCola);
      expect(isNationalTeamCode('FWC'), isFalse);
      expect(isNationalTeamCode('CC'), isFalse);
    });
  });

  group('StickerAlbumGroup', () {
    test('extension matches team code', () {
      const mex = Sticker(
        code: 'MEX1',
        teamCode: 'MEX',
        teamName: 'Mexico',
        slotNumber: 1,
        category: 'player',
        group: 'Group',
      );
      const cc = Sticker(
        code: 'CC1',
        teamCode: 'CC',
        teamName: 'Spain',
        slotNumber: 1,
        category: 'coca_cola',
        group: 'Coca-Cola',
      );
      expect(mex.isNationalTeam, isTrue);
      expect(mex.albumGroupKind, AlbumGroupKind.nationalTeam);
      expect(cc.isNationalTeam, isFalse);
      expect(cc.albumGroupKind, AlbumGroupKind.cocaCola);
    });
  });
}
