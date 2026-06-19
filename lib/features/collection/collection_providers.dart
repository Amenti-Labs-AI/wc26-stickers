import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> removeScannedMissing(String code) async {
    await _db.removeScannedMissingCode(code);
    state = const AsyncData(null);
  }
}

final collectionNotifierProvider =
    StateNotifierProvider<CollectionNotifier, AsyncValue<void>>((ref) {
  return CollectionNotifier(ref.watch(databaseProvider));
});
