import '../data/models/sticker.dart';
import 'album_group.dart';
import 'parallel_kind.dart';

class AlbumNeedBreakdown {
  const AlbumNeedBreakdown({
    required this.nationalTeamStickerCount,
    required this.nationalTeamGroupCount,
    required this.fwcCount,
    required this.cocaColaCount,
    required this.allEntries,
  });

  final int nationalTeamStickerCount;
  final int nationalTeamGroupCount;
  final int fwcCount;
  final int cocaColaCount;
  final List<MapEntry<String, List<Sticker>>> allEntries;

  int get total => nationalTeamStickerCount + fwcCount + cocaColaCount;

  static AlbumNeedBreakdown from(Map<String, List<Sticker>> byTeam) {
    var teamStickers = 0;
    var teamGroups = 0;
    var fwc = 0;
    var coke = 0;
    final entries = <MapEntry<String, List<Sticker>>>[];

    for (final entry in byTeam.entries) {
      if (entry.value.isEmpty) continue;
      entries.add(entry);
      final count = entry.value.length;
      switch (albumGroupKindForCode(entry.key)) {
        case AlbumGroupKind.fwc:
          fwc += count;
        case AlbumGroupKind.cocaCola:
          coke += count;
        case AlbumGroupKind.nationalTeam:
          teamStickers += count;
          teamGroups++;
      }
    }

    return AlbumNeedBreakdown(
      nationalTeamStickerCount: teamStickers,
      nationalTeamGroupCount: teamGroups,
      fwcCount: fwc,
      cocaColaCount: coke,
      allEntries: entries,
    );
  }
}

class AlbumSwapBreakdown {
  const AlbumSwapBreakdown({
    required this.nationalTeamSwapCount,
    required this.nationalTeamGroupCount,
    required this.fwcSwapCount,
    required this.cocaColaSwapCount,
    required this.allEntries,
  });

  final int nationalTeamSwapCount;
  final int nationalTeamGroupCount;
  final int fwcSwapCount;
  final int cocaColaSwapCount;
  final List<MapEntry<String, List<Sticker>>> allEntries;

  int get totalSwaps =>
      nationalTeamSwapCount + fwcSwapCount + cocaColaSwapCount;

  static AlbumSwapBreakdown from(Map<String, List<Sticker>> byTeam) {
    var teamSwaps = 0;
    var teamGroups = 0;
    var fwc = 0;
    var coke = 0;
    final entries = <MapEntry<String, List<Sticker>>>[];

    for (final entry in byTeam.entries) {
      if (entry.value.isEmpty) continue;
      final swaps = entry.value.fold<int>(0, (s, st) => s + st.swapCount);
      if (swaps == 0) continue;
      entries.add(entry);
      switch (albumGroupKindForCode(entry.key)) {
        case AlbumGroupKind.fwc:
          fwc += swaps;
        case AlbumGroupKind.cocaCola:
          coke += swaps;
        case AlbumGroupKind.nationalTeam:
          teamSwaps += swaps;
          teamGroups++;
      }
    }

    return AlbumSwapBreakdown(
      nationalTeamSwapCount: teamSwaps,
      nationalTeamGroupCount: teamGroups,
      fwcSwapCount: fwc,
      cocaColaSwapCount: coke,
      allEntries: entries,
    );
  }
}

class AlbumParallelBreakdown {
  const AlbumParallelBreakdown({
    required this.nationalTeamParallelCount,
    required this.nationalTeamGroupCount,
    required this.fwcParallelCount,
    required this.cocaColaParallelCount,
    required this.allEntries,
  });

  final int nationalTeamParallelCount;
  final int nationalTeamGroupCount;
  final int fwcParallelCount;
  final int cocaColaParallelCount;
  final List<MapEntry<String, List<Sticker>>> allEntries;

  int get totalParallels =>
      nationalTeamParallelCount + fwcParallelCount + cocaColaParallelCount;

  static AlbumParallelBreakdown from(Map<String, List<Sticker>> byTeam) {
    var teamParallels = 0;
    var teamGroups = 0;
    var fwc = 0;
    var coke = 0;
    final entries = <MapEntry<String, List<Sticker>>>[];

    for (final entry in byTeam.entries) {
      if (entry.value.isEmpty) continue;
      final count =
          entry.value.fold<int>(0, (s, st) => s + st.parallelSwapCount);
      if (count == 0) continue;
      entries.add(entry);
      switch (albumGroupKindForCode(entry.key)) {
        case AlbumGroupKind.fwc:
          fwc += count;
        case AlbumGroupKind.cocaCola:
          coke += count;
        case AlbumGroupKind.nationalTeam:
          teamParallels += count;
          teamGroups++;
      }
    }

    return AlbumParallelBreakdown(
      nationalTeamParallelCount: teamParallels,
      nationalTeamGroupCount: teamGroups,
      fwcParallelCount: fwc,
      cocaColaParallelCount: coke,
      allEntries: entries,
    );
  }
}

int _compareStickersByTeamSlot(Sticker a, Sticker b) {
  final byTeam = a.teamCode.compareTo(b.teamCode);
  if (byTeam != 0) return byTeam;
  final bySlot = a.slotNumber.compareTo(b.slotNumber);
  if (bySlot != 0) return bySlot;
  return a.code.compareTo(b.code);
}

/// Share/copy text for need: one sticker per line, sorted by team then slot.
String formatNeedExport(Iterable<Sticker> stickers) {
  final need = stickers.toList()..sort(_compareStickersByTeamSlot);
  return need.map((s) => s.code).join('\n');
}

String formatNeedExportFromTeams(
  List<MapEntry<String, List<Sticker>>> teams,
) =>
    formatNeedExport(teams.expand((e) => e.value));

/// Share/copy text for swaps (base duplicates only): CODE - count per line.
String formatSwapsExport(Iterable<Sticker> stickers) {
  final withSwaps = stickers.where((s) => s.swapCount > 0).toList()
    ..sort(_compareStickersByTeamSlot);
  return withSwaps.map((s) => '${s.code} - ${s.swapCount}').join('\n');
}

String formatSwapsExportFromTeams(
  List<MapEntry<String, List<Sticker>>> teams,
) =>
    formatSwapsExport(teams.expand((e) => e.value));

/// Share/copy text for parallels: grouped by color (rarest first), team/slot
/// within each group, blank line between groups.
String formatParallelsExport(Iterable<Sticker> stickers) {
  final byKind = <ParallelKind, List<({Sticker sticker, int count})>>{};
  for (final sticker in stickers) {
    if (!stickerSupportsParallels(sticker)) continue;
    for (final kind in ParallelKind.orderedByRarity) {
      final count = sticker.parallelCounts[kind] ?? 0;
      if (count <= 0) continue;
      byKind.putIfAbsent(kind, () => []).add((sticker: sticker, count: count));
    }
  }

  final groupTexts = <String>[];
  for (final kind in ParallelKind.orderedByRarity.reversed) {
    final entries = byKind[kind];
    if (entries == null || entries.isEmpty) continue;
    entries.sort((a, b) => _compareStickersByTeamSlot(a.sticker, b.sticker));
    groupTexts.add(
      entries
          .map((e) => '${e.sticker.code} ${kind.displayLabel} - ${e.count}')
          .join('\n'),
    );
  }
  return groupTexts.join('\n\n');
}

String formatParallelsExportFromTeams(
  List<MapEntry<String, List<Sticker>>> teams,
) =>
    formatParallelsExport(teams.expand((e) => e.value));
