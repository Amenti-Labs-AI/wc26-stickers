import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/parallel_kind.dart';

/// Bundled ungraded USD estimates (SportsCardsPro-style eBay aggregates).
class ParallelPriceGuide {
  const ParallelPriceGuide({
    required this.defaultsByKind,
    required this.specificPrices,
    this.updatedAt,
    this.source,
  });

  final Map<ParallelKind, double> defaultsByKind;
  final Map<String, Map<ParallelKind, double>> specificPrices;
  final String? updatedAt;
  final String? source;

  /// Resolves unit price; uses kind default when no sticker-specific entry.
  ({double price, bool isEstimate}) unitPrice(String code, ParallelKind kind) {
    final upper = code.toUpperCase();
    final specific = specificPrices[upper]?[kind];
    if (specific != null) {
      return (price: specific, isEstimate: false);
    }
    final fallback = defaultsByKind[kind];
    if (fallback != null) {
      return (price: fallback, isEstimate: true);
    }
    return (price: 0, isEstimate: true);
  }

  static Future<ParallelPriceGuide> load() async {
    final raw =
        await rootBundle.loadString('assets/catalog/parallel_prices.json');
    return ParallelPriceGuide.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  factory ParallelPriceGuide.fromJson(Map<String, dynamic> json) {
    final defaultsRaw =
        json['defaults_by_kind'] as Map<String, dynamic>? ?? {};
    final defaults = <ParallelKind, double>{};
    for (final kind in ParallelKind.values) {
      final v = defaultsRaw[kind.storageKey];
      if (v is num) defaults[kind] = v.toDouble();
    }

    final pricesRaw = json['prices'] as Map<String, dynamic>? ?? {};
    final specific = <String, Map<ParallelKind, double>>{};
    for (final entry in pricesRaw.entries) {
      final code = entry.key.toUpperCase();
      final kinds = entry.value as Map<String, dynamic>;
      final map = <ParallelKind, double>{};
      for (final kind in ParallelKind.values) {
        final v = kinds[kind.storageKey];
        if (v is num) map[kind] = v.toDouble();
      }
      if (map.isNotEmpty) specific[code] = map;
    }

    return ParallelPriceGuide(
      defaultsByKind: defaults,
      specificPrices: specific,
      updatedAt: json['updated_at'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// One held parallel line for stats display.
class ParallelHoldingLine {
  const ParallelHoldingLine({
    required this.code,
    required this.displayName,
    required this.kind,
    required this.count,
    required this.unitPrice,
    required this.isEstimate,
  });

  final String code;
  final String displayName;
  final ParallelKind kind;
  final int count;
  final double unitPrice;
  final bool isEstimate;

  double get lineTotal => unitPrice * count;
}

class ParallelInventoryStats {
  const ParallelInventoryStats({
    required this.holdings,
    required this.countByKind,
    required this.totalEstimatedValue,
    required this.needStickerWithParallelCount,
  });

  final List<ParallelHoldingLine> holdings;
  final Map<ParallelKind, int> countByKind;
  final double totalEstimatedValue;
  /// Stickers marked Need that still have parallel inventory.
  final int needStickerWithParallelCount;

  int get totalParallelCount =>
      countByKind.values.fold<int>(0, (sum, n) => sum + n);

  String get parallelsSummarySubtitle {
    final base = '$totalParallelCount parallels';
    if (needStickerWithParallelCount <= 0) return base;
    return '$base · $needStickerWithParallelCount need';
  }
}
