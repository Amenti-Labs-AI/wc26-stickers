import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

void main() {
  const code = 'MEX4';

  group('Sticker helpers', () {
    test('swapCount is owned_count minus one', () {
      const owned = Sticker(
        code: code,
        teamCode: 'MEX',
        teamName: 'Mexico',
        slotNumber: 4,
        category: 'player',
        group: 'Group',
        ownedCount: 4,
      );
      expect(owned.swapCount, 3);
      expect(owned.copyWith(ownedCount: 1).swapCount, 0);
    });

    test('isNeed when scanned or owned_count is zero', () {
      const sticker = Sticker(
        code: code,
        teamCode: 'MEX',
        teamName: 'Mexico',
        slotNumber: 4,
        category: 'player',
        group: 'Group',
        ownedCount: 1,
      );
      expect(sticker.isNeed({}), isFalse);
      expect(sticker.isNeed({code}), isTrue);
      expect(sticker.copyWith(ownedCount: 0).isNeed({}), isTrue);
    });

    test('teamSectionTitle maps special album sections', () {
      const cc = Sticker(
        code: 'CC1',
        teamCode: 'CC',
        teamName: 'Spain',
        slotNumber: 1,
        category: 'coca_cola',
        group: 'Coca-Cola',
      );
      const fwc = Sticker(
        code: 'FWC0',
        teamCode: 'FWC',
        teamName: 'FIFA World Cup',
        slotNumber: 0,
        category: 'fwc_foil',
        group: 'FWC',
      );
      const mex = Sticker(
        code: 'MEX1',
        teamCode: 'MEX',
        teamName: 'Mexico',
        slotNumber: 1,
        category: 'player',
        group: 'Group A',
      );
      expect(cc.teamSectionTitle, 'Coca-Cola');
      expect(fwc.teamSectionTitle, 'FIFA World Cup');
      expect(mex.teamSectionTitle, 'Mexico');
    });
  });

  group('applyStickerState owned_count mapping', () {
    int ownedFor({required bool need, int swaps = 0}) =>
        need ? 0 : (1 + swaps).clamp(1, 999);

    test('need zeroes owned_count', () {
      expect(ownedFor(need: true), 0);
    });

    test('owned with swaps is one plus swaps', () {
      expect(ownedFor(need: false, swaps: 0), 1);
      expect(ownedFor(need: false, swaps: 2), 3);
    });
  });
}
