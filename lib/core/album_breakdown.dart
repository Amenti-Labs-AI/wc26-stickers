import '../data/models/sticker.dart';
import 'album_group.dart';

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
