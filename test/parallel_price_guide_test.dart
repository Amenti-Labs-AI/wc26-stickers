import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/parallel_kind.dart';
import 'package:panini_wc26_tracker/data/models/parallel_price_guide.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == 'assets/catalog/parallel_prices.json') {
        return const StringCodec().encodeMessage('''
{
  "version": 1,
  "source": "test",
  "updated_at": "2026-06-30",
  "defaults_by_kind": {
    "blue": 10.0,
    "red": 40.0,
    "purple": 80.0,
    "green": 200.0,
    "black": 1000.0
  },
  "prices": {
    "ARG17": {
      "blue": 21.0,
      "purple": 460.0
    }
  }
}
''');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  group('ParallelPriceGuide', () {
    test('loads bundled asset and resolves specific prices', () async {
      final guide = await ParallelPriceGuide.load();
      final argBlue = guide.unitPrice('ARG17', ParallelKind.blue);
      expect(argBlue.price, 21.0);
      expect(argBlue.isEstimate, isFalse);

      final argGreen = guide.unitPrice('ARG17', ParallelKind.green);
      expect(argGreen.price, 200.0);
      expect(argGreen.isEstimate, isTrue);
    });

    test('holdings sort by unit price descending', () {
      const guide = ParallelPriceGuide(
        defaultsByKind: {
          ParallelKind.blue: 10,
          ParallelKind.red: 40,
          ParallelKind.purple: 80,
          ParallelKind.green: 200,
          ParallelKind.black: 1000,
        },
        specificPrices: {
          'ARG17': {ParallelKind.purple: 460},
          'POR15': {ParallelKind.blue: 102.5},
        },
      );

      final holdings = <ParallelHoldingLine>[
        ParallelHoldingLine(
          code: 'POR15',
          displayName: 'Ronaldo',
          kind: ParallelKind.blue,
          count: 1,
          unitPrice: guide.unitPrice('POR15', ParallelKind.blue).price,
          isEstimate: false,
        ),
        ParallelHoldingLine(
          code: 'ARG17',
          displayName: 'Messi',
          kind: ParallelKind.purple,
          count: 1,
          unitPrice: guide.unitPrice('ARG17', ParallelKind.purple).price,
          isEstimate: false,
        ),
      ]..sort((a, b) => b.unitPrice.compareTo(a.unitPrice));

      expect(holdings.first.code, 'ARG17');
      expect(holdings.last.code, 'POR15');
    });

    test('parallelsSummarySubtitle includes need sticker count', () {
      const stats = ParallelInventoryStats(
        holdings: [],
        countByKind: {ParallelKind.blue: 5},
        totalEstimatedValue: 0,
        needStickerWithParallelCount: 2,
      );
      expect(stats.parallelsSummarySubtitle, '5 parallels · 2 need');
      expect(
        const ParallelInventoryStats(
          holdings: [],
          countByKind: {},
          totalEstimatedValue: 0,
          needStickerWithParallelCount: 0,
        ).parallelsSummarySubtitle,
        '0 parallels',
      );
    });
  });
}
