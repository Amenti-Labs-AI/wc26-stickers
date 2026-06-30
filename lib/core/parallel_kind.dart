import 'package:flutter/material.dart';

import '../data/models/sticker.dart';

/// North American WC26 parallel border colors (standard pack chase).
enum ParallelKind {
  blue,
  red,
  purple,
  green,
  black;

  String get storageKey => name;

  String get displayLabel {
    switch (this) {
      case ParallelKind.blue:
        return 'Blue';
      case ParallelKind.red:
        return 'Red';
      case ParallelKind.purple:
        return 'Purple';
      case ParallelKind.green:
        return 'Green';
      case ParallelKind.black:
        return 'Black';
    }
  }

  /// Collector-facing pack odds (NA retail boxes).
  String get oddsLabel {
    switch (this) {
      case ParallelKind.blue:
        return '1:2';
      case ParallelKind.red:
        return '1:25';
      case ParallelKind.purple:
        return '1:200';
      case ParallelKind.green:
        return '1:1,400';
      case ParallelKind.black:
        return '1/1';
    }
  }

  /// Higher rank = rarer (for sorting banners and stats).
  int get rarityRank {
    switch (this) {
      case ParallelKind.blue:
        return 1;
      case ParallelKind.red:
        return 2;
      case ParallelKind.purple:
        return 3;
      case ParallelKind.green:
        return 4;
      case ParallelKind.black:
        return 5;
    }
  }

  Color get borderColor {
    switch (this) {
      case ParallelKind.blue:
        return const Color(0xFF1565C0);
      case ParallelKind.red:
        return const Color(0xFFC62828);
      case ParallelKind.purple:
        return const Color(0xFF6A1B9A);
      case ParallelKind.green:
        return const Color(0xFF2E7D32);
      case ParallelKind.black:
        return const Color(0xFF212121);
    }
  }

  Color chipForeground(ColorScheme scheme) =>
      this == ParallelKind.black ? Colors.white : Colors.white;

  static ParallelKind? fromStorageKey(String key) {
    for (final k in ParallelKind.values) {
      if (k.storageKey == key) return k;
    }
    return null;
  }

  static List<ParallelKind> get orderedByRarity =>
      List<ParallelKind>.from(values)
        ..sort((a, b) => a.rarityRank.compareTo(b.rarityRank));

  static List<ParallelKind> kindsWithCounts(Map<ParallelKind, int> counts) {
    return orderedByRarity
        .where((k) => (counts[k] ?? 0) > 0)
        .toList();
  }
}

/// Parallels apply to non-foil catalog stickers only.
bool stickerSupportsParallels(Sticker sticker) {
  return sticker.category != 'fwc_foil' && sticker.category != 'fwc_museum';
}
