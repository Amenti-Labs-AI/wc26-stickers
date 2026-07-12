/// How a fresh or reset collection is initialized.
enum CollectionStartMode {
  /// All stickers owned; scan empty slots to mark Need.
  ownedScan,

  /// All stickers missing (owned_count = 0); mark owned as you go.
  allMissing;

  String get storageKey => switch (this) {
        CollectionStartMode.ownedScan => 'owned_scan',
        CollectionStartMode.allMissing => 'all_missing',
      };

  static CollectionStartMode? fromStorageKey(String? raw) {
    return switch (raw) {
      'owned_scan' => CollectionStartMode.ownedScan,
      'all_missing' => CollectionStartMode.allMissing,
      _ => null,
    };
  }

  String get title => switch (this) {
        CollectionStartMode.ownedScan => 'Start with everything owned',
        CollectionStartMode.allMissing => 'Start with an empty collection',
      };

  String get description => switch (this) {
        CollectionStartMode.ownedScan =>
          'Album mostly filled. Scan empty slots for Need. Red = need, yellow = owned.',
        CollectionStartMode.allMissing =>
          'Starting from scratch. Mark stickers owned in Collection as you get them.',
      };
}
