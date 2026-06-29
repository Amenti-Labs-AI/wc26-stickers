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
