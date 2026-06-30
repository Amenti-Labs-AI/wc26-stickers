import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/parallel_kind.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

void main() {
  const base = Sticker(
    code: 'ARG17',
    teamCode: 'ARG',
    teamName: 'Argentina',
    slotNumber: 17,
    playerName: 'Lionel Messi',
    category: 'player',
    group: 'Group',
    ownedCount: 1,
    parallelCounts: {
      ParallelKind.blue: 2,
      ParallelKind.purple: 1,
    },
  );

  group('parallel swap counts', () {
    test('parallelSwapCount sums parallel inventory', () {
      expect(base.parallelSwapCount, 3);
    });

    test('totalSwapCount includes base and parallel swaps', () {
      expect(base.copyWith(ownedCount: 3).totalSwapCount, 5);
    });

    test('hasParallels when any parallel held', () {
      expect(base.hasParallels, isTrue);
      expect(
        base.copyWith(parallelCounts: const {}).hasParallels,
        isFalse,
      );
    });
  });

  group('owned/need unaffected by parallels', () {
    test('isNeed ignores parallel counts', () {
      expect(base.isNeed({}), isFalse);
      expect(base.copyWith(ownedCount: 0).isNeed({}), isTrue);
    });

    test('isOwned ignores parallel counts', () {
      expect(base.copyWith(ownedCount: 0).isOwned, isFalse);
      expect(base.isOwned, isTrue);
    });
  });

  group('topParallelKinds', () {
    test('returns held kinds ordered by rarity', () {
      expect(
        base.topParallelKinds,
        [ParallelKind.blue, ParallelKind.purple],
      );
    });
  });
}
