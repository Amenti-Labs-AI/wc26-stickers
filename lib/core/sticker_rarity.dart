import 'package:flutter/material.dart';

import '../data/models/sticker.dart';

enum StickerRarityKind { cocaCola, fwcMuseum, fwcFoil, badge, scarce }

/// Market-scarce base player stickers (FanLink / collector reports, not parallels).
const scarceStickerCodes = {
  'CRO20',
  'BIH4',
  'IRQ16',
  'KOR20',
  'JPN17',
  'JOR6',
  'ECU4',
  'AUT6',
  'URU3',
  'USA3',
  'NED4',
  'BRA12',
  'SWE16',
};

class StickerRarity {
  const StickerRarity(this.kind);

  final StickerRarityKind kind;

  String get chipLabel => switch (kind) {
        StickerRarityKind.cocaCola => 'Coke',
        StickerRarityKind.fwcMuseum => 'Museum',
        StickerRarityKind.fwcFoil => 'Foil',
        StickerRarityKind.badge => 'Badge',
        StickerRarityKind.scarce => 'Scarce',
      };

  Color chipBackground(ColorScheme scheme) => switch (kind) {
        StickerRarityKind.cocaCola =>
          scheme.errorContainer.withValues(alpha: 0.55),
        _ => scheme.surfaceContainerHigh,
      };

  Color chipForeground(ColorScheme scheme) => switch (kind) {
        StickerRarityKind.cocaCola => scheme.onErrorContainer,
        _ => scheme.onSurfaceVariant,
      };
}

StickerRarity? rarityFor(Sticker sticker) {
  switch (sticker.category) {
    case 'coca_cola':
      return const StickerRarity(StickerRarityKind.cocaCola);
    case 'fwc_museum':
      return const StickerRarity(StickerRarityKind.fwcMuseum);
    case 'fwc_foil':
      return const StickerRarity(StickerRarityKind.fwcFoil);
    case 'badge':
      return const StickerRarity(StickerRarityKind.badge);
    case 'player':
    case 'team_photo':
      if (scarceStickerCodes.contains(sticker.code.toUpperCase())) {
        return const StickerRarity(StickerRarityKind.scarce);
      }
      return null;
    default:
      return null;
  }
}
