import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/album_breakdown.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

void main() {
  group('AlbumNeedBreakdown', () {
    test('groups national teams separately from FWC and CC', () {
      final byTeam = {
        'MEX': [
          const Sticker(
            code: 'MEX1',
            teamCode: 'MEX',
            teamName: 'Mexico',
            slotNumber: 1,
            category: 'player',
            group: 'Group',
          ),
        ],
        'FWC': [
          const Sticker(
            code: 'FWC1',
            teamCode: 'FWC',
            teamName: 'FIFA World Cup',
            slotNumber: 1,
            category: 'fwc_foil',
            group: 'FWC',
          ),
        ],
        'CC': [
          const Sticker(
            code: 'CC1',
            teamCode: 'CC',
            teamName: 'Spain',
            slotNumber: 1,
            category: 'coca_cola',
            group: 'Coca-Cola',
          ),
          const Sticker(
            code: 'CC2',
            teamCode: 'CC',
            teamName: 'Germany',
            slotNumber: 2,
            category: 'coca_cola',
            group: 'Coca-Cola',
          ),
        ],
      };

      final breakdown = AlbumNeedBreakdown.from(byTeam);
      expect(breakdown.nationalTeamStickerCount, 1);
      expect(breakdown.nationalTeamGroupCount, 1);
      expect(breakdown.fwcCount, 1);
      expect(breakdown.cocaColaCount, 2);
      expect(breakdown.total, 4);
    });
  });

  group('AlbumSwapBreakdown', () {
    test('counts swaps by album group kind', () {
      final byTeam = {
        'BRA': [
          Sticker(
            code: 'BRA1',
            teamCode: 'BRA',
            teamName: 'Brazil',
            slotNumber: 1,
            category: 'player',
            group: 'Group',
            ownedCount: 3,
          ),
        ],
        'CC': [
          Sticker(
            code: 'CC1',
            teamCode: 'CC',
            teamName: 'Spain',
            slotNumber: 1,
            category: 'coca_cola',
            group: 'Coca-Cola',
            ownedCount: 2,
          ),
        ],
      };

      final breakdown = AlbumSwapBreakdown.from(byTeam);
      expect(breakdown.nationalTeamSwapCount, 2);
      expect(breakdown.nationalTeamGroupCount, 1);
      expect(breakdown.cocaColaSwapCount, 1);
      expect(breakdown.totalSwaps, 3);
    });
  });
}
