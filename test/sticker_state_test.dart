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
