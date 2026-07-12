import '../data/models/sticker.dart';

/// How a sticker group is categorized in the album.
enum AlbumGroupKind {
  nationalTeam,
  fwc,
  cocaCola,
}

const fwcTeamCode = 'FWC';
const cocaColaTeamCode = 'CC';

AlbumGroupKind albumGroupKindForCode(String teamCode) {
  switch (teamCode.toUpperCase()) {
    case fwcTeamCode:
      return AlbumGroupKind.fwc;
    case cocaColaTeamCode:
      return AlbumGroupKind.cocaCola;
    default:
      return AlbumGroupKind.nationalTeam;
  }
}

bool isNationalTeamCode(String teamCode) =>
    albumGroupKindForCode(teamCode) == AlbumGroupKind.nationalTeam;

extension StickerAlbumGroup on Sticker {
  AlbumGroupKind get albumGroupKind => albumGroupKindForCode(teamCode);

  bool get isNationalTeam => albumGroupKind == AlbumGroupKind.nationalTeam;
}

/// Sort key for Collection team sections in physical album order.
int albumSectionRank(Sticker sticker) {
  switch (albumGroupKindForCode(sticker.teamCode)) {
    case AlbumGroupKind.fwc:
      return 0;
    case AlbumGroupKind.nationalTeam:
      return 1;
    case AlbumGroupKind.cocaCola:
      return 2;
  }
}

/// Compare two teams' representative stickers for album / group order.
int compareStickersByAlbumOrder(Sticker a, Sticker b) {
  final section = albumSectionRank(a).compareTo(albumSectionRank(b));
  if (section != 0) return section;

  final group = a.group.compareTo(b.group);
  if (group != 0) return group;

  final pageA = a.albumPage ?? 1 << 30;
  final pageB = b.albumPage ?? 1 << 30;
  final page = pageA.compareTo(pageB);
  if (page != 0) return page;

  return a.teamCode.compareTo(b.teamCode);
}

/// Compare by display section title (A–Z), then team code.
int compareStickersByTeamName(Sticker a, Sticker b) {
  final name = a.teamSectionTitle.compareTo(b.teamSectionTitle);
  if (name != 0) return name;
  return a.teamCode.compareTo(b.teamCode);
}

/// Earliest printed album page for a team section (start of the spread).
int? albumPageNumber(Iterable<Sticker> stickers) {
  int? earliest;
  for (final s in stickers) {
    final page = s.albumPage;
    if (page == null) continue;
    if (earliest == null || page < earliest) earliest = page;
  }
  return earliest;
}
