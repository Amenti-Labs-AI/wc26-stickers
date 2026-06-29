import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/album_group.dart';
import '../../data/database/app_database.dart';
import '../../data/models/sticker.dart';
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final collectionStatsProvider = FutureProvider<CollectionStats>((ref) async {
  return AppDatabase.instance.getStats();
});

final stickersProvider =
    FutureProvider.family<List<Sticker>, StickerQuery>((ref, query) async {
  return AppDatabase.instance.getAllStickers(
    query: query.search,
    filter: query.filter,
  );
});

final groupedStickersProvider =
    FutureProvider.family<Map<String, List<Sticker>>, StickerQuery>(
        (ref, query) async {
  final stickers = await AppDatabase.instance.getAllStickers(
    query: query.search,
    filter: query.filter,
  );
  final byTeam = <String, List<Sticker>>{};
  for (final s in stickers) {
    byTeam.putIfAbsent(s.teamCode, () => []).add(s);
  }
  for (final list in byTeam.values) {
    list.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
  }
  return byTeam;
});

final scannedMissingCodesProvider = FutureProvider<Set<String>>((ref) async {
  return AppDatabase.instance.getScannedMissingCodes();
});

/// Teams with at least one sticker confirmed missing via live scan.
final scannedMissingByTeamProvider =
    FutureProvider<Map<String, List<Sticker>>>((ref) async {
  return AppDatabase.instance.getGroupedByTeam(
    filter: StickerFilter.scannedMissing,
  );
});

/// Teams with at least one swap (owned_count >= 2).
final swapsByTeamProvider =
    FutureProvider<Map<String, List<Sticker>>>((ref) async {
  return AppDatabase.instance.getGroupedByTeam(
    filter: StickerFilter.duplicates,
  );
});

class TeamCollectionStat {
  const TeamCollectionStat({
    required this.teamCode,
    required this.label,
    required this.swaps,
    required this.need,
    required this.owned,
    required this.total,
  });

  final String teamCode;
  final String label;
  final int swaps;
  final int need;
  final int owned;
  final int total;

  double get completionPercent => total == 0 ? 0 : (owned / total) * 100;

  bool get isNationalTeam => isNationalTeamCode(teamCode);

  AlbumGroupKind get albumGroupKind => albumGroupKindForCode(teamCode);
}

class AlbumGroupStats {
  const AlbumGroupStats({
    required this.nationalTeamCount,
    required this.nationalTeamsComplete,
    required this.fwcComplete,
    required this.cocaColaComplete,
    required this.fwcSwaps,
    required this.cocaColaSwaps,
    required this.fwcNeed,
    required this.cocaColaNeed,
  });

  final int nationalTeamCount;
  final int nationalTeamsComplete;
  final bool fwcComplete;
  final bool cocaColaComplete;
  final int fwcSwaps;
  final int cocaColaSwaps;
  final int fwcNeed;
  final int cocaColaNeed;

  static AlbumGroupStats fromTeamStats(List<TeamCollectionStat> stats) {
    var nationalCount = 0;
    var nationalComplete = 0;
    var fwcComplete = false;
    var cokeComplete = false;
    var fwcSwaps = 0;
    var cokeSwaps = 0;
    var fwcNeed = 0;
    var cokeNeed = 0;

    for (final s in stats) {
      switch (s.albumGroupKind) {
        case AlbumGroupKind.fwc:
          fwcSwaps = s.swaps;
          fwcNeed = s.need;
          fwcComplete = s.need == 0 && s.total > 0;
        case AlbumGroupKind.cocaCola:
          cokeSwaps = s.swaps;
          cokeNeed = s.need;
          cokeComplete = s.need == 0 && s.total > 0;
        case AlbumGroupKind.nationalTeam:
          nationalCount++;
          if (s.need == 0 && s.total > 0) nationalComplete++;
      }
    }

    return AlbumGroupStats(
      nationalTeamCount: nationalCount,
      nationalTeamsComplete: nationalComplete,
      fwcComplete: fwcComplete,
      cocaColaComplete: cokeComplete,
      fwcSwaps: fwcSwaps,
      cocaColaSwaps: cokeSwaps,
      fwcNeed: fwcNeed,
      cocaColaNeed: cokeNeed,
    );
  }

  static List<TeamCollectionStat> nationalTeamsOnly(
    List<TeamCollectionStat> stats,
  ) =>
      stats.where((s) => s.isNationalTeam).toList();
}

final teamCollectionStatsProvider =
    FutureProvider<List<TeamCollectionStat>>((ref) async {
  final stickers = await AppDatabase.instance.getAllStickers();
  final scannedMissing = await AppDatabase.instance.getScannedMissingCodes();
  final byTeam = <String, List<Sticker>>{};
  for (final s in stickers) {
    byTeam.putIfAbsent(s.teamCode, () => []).add(s);
  }

  return byTeam.entries.map((entry) {
    final teamStickers = entry.value;
    final label = teamStickers.first.teamSectionTitle;
    var swaps = 0;
    var need = 0;
    var owned = 0;
    for (final s in teamStickers) {
      swaps += s.swapCount;
      if (s.isNeed(scannedMissing)) {
        need++;
      } else {
        owned++;
      }
    }
    return TeamCollectionStat(
      teamCode: entry.key,
      label: label,
      swaps: swaps,
      need: need,
      owned: owned,
      total: teamStickers.length,
    );
  }).toList()
    ..sort((a, b) => a.label.compareTo(b.label));
});

class StickerQuery {
  const StickerQuery({this.search, this.filter = StickerFilter.all});

  final String? search;
  final StickerFilter filter;

  @override
  bool operator ==(Object other) =>
      other is StickerQuery && other.search == search && other.filter == filter;

  @override
  int get hashCode => Object.hash(search, filter);
}

class CollectionNotifier extends StateNotifier<AsyncValue<void>> {
  CollectionNotifier(this._db) : super(const AsyncData(null));

  final AppDatabase _db;

  Future<void> setCount(String code, int count) async {
    state = const AsyncLoading();
    try {
      await _db.setOwnedCount(code, count);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> increment(String code) async {
    await _db.incrementOwned(code);
    state = const AsyncData(null);
  }

  Future<void> mergeOwned(Iterable<String> codes) async {
    await _db.mergeOwnedCodes(codes);
    state = const AsyncData(null);
  }

  Future<void> mergeScannedMissing(Iterable<String> codes) async {
    await _db.mergeScannedMissingCodes(codes);
    state = const AsyncData(null);
  }

  Future<void> markOwned(String code) async {
    state = const AsyncLoading();
    try {
      await _db.markStickerOwned(code);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markMissing(String code) async {
    state = const AsyncLoading();
    try {
      await _db.mergeScannedMissingCodes([code]);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> applyStickerState(
    String code, {
    required bool need,
    int swaps = 0,
  }) async {
    state = const AsyncLoading();
    try {
      await _db.applyStickerState(code, need: need, swaps: swaps);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> removeScannedMissing(String code) async {
    await _db.removeScannedMissingCode(code);
    state = const AsyncData(null);
  }
}

final collectionNotifierProvider =
    StateNotifierProvider<CollectionNotifier, AsyncValue<void>>((ref) {
  return CollectionNotifier(ref.watch(databaseProvider));
});
