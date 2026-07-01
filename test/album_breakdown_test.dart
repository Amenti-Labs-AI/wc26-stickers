import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/album_breakdown.dart';
import 'package:panini_wc26_tracker/core/parallel_kind.dart';
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
    test('counts base swaps by album group kind', () {
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

    test('excludes parallel counts from swap totals', () {
      final byTeam = {
        'ARG': [
          Sticker(
            code: 'ARG17',
            teamCode: 'ARG',
            teamName: 'Argentina',
            slotNumber: 17,
            category: 'player',
            group: 'Group',
            ownedCount: 1,
            parallelCounts: const {ParallelKind.purple: 2},
          ),
        ],
      };

      final breakdown = AlbumSwapBreakdown.from(byTeam);
      expect(breakdown.nationalTeamSwapCount, 0);
      expect(breakdown.totalSwaps, 0);
    });
  });

  group('AlbumParallelBreakdown', () {
    test('counts parallels separately from base swaps', () {
      final byTeam = {
        'ARG': [
          Sticker(
            code: 'ARG17',
            teamCode: 'ARG',
            teamName: 'Argentina',
            slotNumber: 17,
            category: 'player',
            group: 'Group',
            ownedCount: 3,
            parallelCounts: const {ParallelKind.purple: 2},
          ),
        ],
      };

      final breakdown = AlbumParallelBreakdown.from(byTeam);
      expect(breakdown.nationalTeamParallelCount, 2);
      expect(breakdown.totalParallels, 2);
    });
  });

  group('formatNeedExport', () {
    test('newline list sorted by team code then slot', () {
      final text = formatNeedExport([
        const Sticker(
          code: 'MEX16',
          teamCode: 'MEX',
          teamName: 'Mexico',
          slotNumber: 16,
          category: 'player',
          group: 'Group',
        ),
        const Sticker(
          code: 'MEX3',
          teamCode: 'MEX',
          teamName: 'Mexico',
          slotNumber: 3,
          category: 'player',
          group: 'Group',
        ),
        const Sticker(
          code: 'ARG17',
          teamCode: 'ARG',
          teamName: 'Argentina',
          slotNumber: 17,
          category: 'player',
          group: 'Group',
        ),
      ]);
      expect(text, 'ARG17\nMEX3\nMEX16');
    });
  });

  group('formatSwapsExport', () {
    test('newline list uses base swap count only', () {
      final text = formatSwapsExport([
        Sticker(
          code: 'MEX16',
          teamCode: 'MEX',
          teamName: 'Mexico',
          slotNumber: 16,
          category: 'player',
          group: 'Group',
          ownedCount: 1,
          parallelCounts: const {ParallelKind.blue: 1},
        ),
        Sticker(
          code: 'MEX3',
          teamCode: 'MEX',
          teamName: 'Mexico',
          slotNumber: 3,
          category: 'player',
          group: 'Group',
          ownedCount: 3,
        ),
        Sticker(
          code: 'ARG17',
          teamCode: 'ARG',
          teamName: 'Argentina',
          slotNumber: 17,
          category: 'player',
          group: 'Group',
          ownedCount: 1,
          parallelCounts: const {ParallelKind.purple: 2},
        ),
      ]);
      expect(text, 'MEX3 - 2');
    });
  });

  group('formatParallelsExport', () {
    test('groups by color rarest first then team/slot with blank lines', () {
      final text = formatParallelsExport([
        Sticker(
          code: 'MEX16',
          teamCode: 'MEX',
          teamName: 'Mexico',
          slotNumber: 16,
          category: 'player',
          group: 'Group',
          parallelCounts: const {ParallelKind.blue: 1},
        ),
        Sticker(
          code: 'MEX3',
          teamCode: 'MEX',
          teamName: 'Mexico',
          slotNumber: 3,
          category: 'player',
          group: 'Group',
          parallelCounts: const {
            ParallelKind.blue: 2,
            ParallelKind.purple: 1,
          },
        ),
        Sticker(
          code: 'ARG17',
          teamCode: 'ARG',
          teamName: 'Argentina',
          slotNumber: 17,
          category: 'player',
          group: 'Group',
          parallelCounts: const {ParallelKind.purple: 2},
        ),
      ]);
      expect(
        text,
        'ARG17 Purple - 2\n'
        'MEX3 Purple - 1\n'
        '\n'
        'MEX3 Blue - 2\n'
        'MEX16 Blue - 1',
      );
    });
  });
}
