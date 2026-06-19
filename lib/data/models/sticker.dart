class Sticker {
  const Sticker({
    required this.code,
    required this.teamCode,
    required this.teamName,
    required this.slotNumber,
    this.playerName,
    required this.category,
    required this.group,
    this.albumPage,
    this.slotIndexOnPage,
    this.ownedCount = 0,
  });

  final String code;
  final String teamCode;
  final String teamName;
  final int slotNumber;
  final String? playerName;
  final String category;
  final String group;
  final int? albumPage;
  final int? slotIndexOnPage;
  final int ownedCount;

  bool get isMissing => ownedCount == 0;
  bool get isOwned => ownedCount >= 1;
  bool get isDuplicate => ownedCount >= 2;

  String get displayName {
    if (playerName != null && playerName!.isNotEmpty) {
      return playerName!;
    }
    switch (category) {
      case 'badge':
        return '$teamName Badge';
      case 'team_photo':
        return '$teamName Team Photo';
      default:
        return code;
    }
  }

  Sticker copyWith({int? ownedCount}) => Sticker(
        code: code,
        teamCode: teamCode,
        teamName: teamName,
        slotNumber: slotNumber,
        playerName: playerName,
        category: category,
        group: group,
        albumPage: albumPage,
        slotIndexOnPage: slotIndexOnPage,
        ownedCount: ownedCount ?? this.ownedCount,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'owned_count': ownedCount,
      };

  factory Sticker.fromCatalogJson(Map<String, dynamic> json, {int ownedCount = 0}) {
    return Sticker(
      code: json['code'] as String,
      teamCode: json['team_code'] as String,
      teamName: json['team_name'] as String,
      slotNumber: json['slot_number'] as int,
      playerName: json['player_name'] as String?,
      category: json['category'] as String,
      group: json['group'] as String,
      albumPage: json['album_page'] as int?,
      slotIndexOnPage: json['slot_index_on_page'] as int?,
      ownedCount: ownedCount,
    );
  }
}

class CollectionStats {
  const CollectionStats({
    required this.total,
    required this.owned,
    required this.scannedMissing,
    required this.duplicates,
  });

  final int total;
  final int owned;
  /// Stickers confirmed missing via live scan only.
  final int scannedMissing;
  final int duplicates;

  double get percent => total == 0 ? 0 : (owned / total) * 100;
}
