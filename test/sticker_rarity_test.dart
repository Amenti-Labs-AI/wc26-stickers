import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/sticker_rarity.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

Sticker _sticker({required String code, required String category}) {
  return Sticker(
    code: code,
    teamCode: code.replaceAll(RegExp(r'\d'), ''),
    teamName: 'Test',
    slotNumber: 1,
    category: category,
    group: 'Group A',
  );
}

void main() {
  group('rarityFor', () {
    test('maps catalog categories', () {
      expect(rarityFor(_sticker(code: 'CC1', category: 'coca_cola'))?.kind,
          StickerRarityKind.cocaCola);
      expect(rarityFor(_sticker(code: 'FWC12', category: 'fwc_museum'))?.kind,
          StickerRarityKind.fwcMuseum);
      expect(rarityFor(_sticker(code: 'FWC3', category: 'fwc_foil'))?.kind,
          StickerRarityKind.fwcFoil);
      expect(rarityFor(_sticker(code: 'BRA1', category: 'badge'))?.kind,
          StickerRarityKind.badge);
    });

    test('maps scarce player codes', () {
      expect(rarityFor(_sticker(code: 'CRO20', category: 'player'))?.kind,
          StickerRarityKind.scarce);
    });

    test('regular player has no rarity', () {
      expect(rarityFor(_sticker(code: 'BRA14', category: 'player')), isNull);
    });

    test('category tier beats scarce list', () {
      expect(rarityFor(_sticker(code: 'CC1', category: 'coca_cola'))?.kind,
          StickerRarityKind.cocaCola);
    });

    test('chip labels', () {
      expect(
        const StickerRarity(StickerRarityKind.cocaCola).chipLabel,
        'Coke',
      );
      expect(
        const StickerRarity(StickerRarityKind.scarce).chipLabel,
        'Scarce',
      );
    });
  });
}
