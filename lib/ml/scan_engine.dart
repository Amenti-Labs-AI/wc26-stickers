/// Live Scan engine registry (`docs/ml/strategy.md`).
///
/// Add enum values and dedicated scanner classes for new scan pipelines.
enum ScanEngine {
  portraitOcr;

  String get storageKey => name;

  String get displayName => switch (this) {
        ScanEngine.portraitOcr => 'Scanning',
      };

  String get subtitle => switch (this) {
        ScanEngine.portraitOcr => 'How to scan album pages',
      };

  String get modesTitle => 'Collection modes';

  String get modesSubtitle => 'How your collection starts';

  /// Collection start modes (Settings → Instructions).
  List<String> get modeBullets => switch (this) {
        ScanEngine.portraitOcr => const [
              'Scan for gaps — all stickers start owned. Scan empty slots to '
                  'build Need.',
              'Empty collection — all start missing. Mark owned in Collection '
                  'as you get them.',
              'Choose on first launch, or later under Reset collection.',
            ],
      };

  /// Live scanning (Settings → Instructions).
  List<String> get scanBullets => switch (this) {
        ScanEngine.portraitOcr => const [
              'Point the camera at a page to read empty slot codes (e.g. MEX 4).',
              'Locks onto the team page for accurate matches.',
              'Red = Need (saved). Yellow = owned (visual only).',
            ],
      };

  /// Combined bullets (modes then scanning) for tests / legacy callers.
  List<String> get detailBullets => [...modeBullets, ...scanBullets];

  static ScanEngine fromStorage(String? raw) {
    // Live scan always uses portrait OCR; legacy prefs are ignored.
    return ScanEngine.portraitOcr;
  }
}
