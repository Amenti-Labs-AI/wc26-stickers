import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/parallel_kind.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

void main() {
  group('ParallelKind', () {
    test('odds labels match NA retail tiers', () {
      expect(ParallelKind.blue.oddsLabel, '1:2');
      expect(ParallelKind.red.oddsLabel, '1:25');
      expect(ParallelKind.purple.oddsLabel, '1:200');
      expect(ParallelKind.green.oddsLabel, '1:1,400');
      expect(ParallelKind.black.oddsLabel, '1/1');
    });

    test('rarity rank orders blue to black', () {
      final ranks = ParallelKind.orderedByRarity.map((k) => k.rarityRank).toList();
      expect(ranks, [1, 2, 3, 4, 5]);
    });

    test('fromStorageKey round-trips', () {
      for (final kind in ParallelKind.values) {
        expect(ParallelKind.fromStorageKey(kind.storageKey), kind);
      }
    });
  });

  group('stickerSupportsParallels', () {
    const player = Sticker(
      code: 'ARG17',
      teamCode: 'ARG',
      teamName: 'Argentina',
      slotNumber: 17,
      category: 'player',
      group: 'Group',
    );
    const foil = Sticker(
      code: 'FWC1',
      teamCode: 'FWC',
      teamName: 'FIFA World Cup',
      slotNumber: 1,
      category: 'fwc_foil',
      group: 'FWC',
    );
    const museum = Sticker(
      code: 'FWC10',
      teamCode: 'FWC',
      teamName: 'FIFA World Cup',
      slotNumber: 10,
      category: 'fwc_museum',
      group: 'FWC',
    );

    test('player stickers support parallels', () {
      expect(stickerSupportsParallels(player), isTrue);
    });

    test('foil and museum stickers do not', () {
      expect(stickerSupportsParallels(foil), isFalse);
      expect(stickerSupportsParallels(museum), isFalse);
    });
  });
}
