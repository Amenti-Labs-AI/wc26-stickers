/// Live Scan engine registry (`docs/ml/strategy.md`).
///
/// Add enum values and dedicated scanner classes for new scan pipelines.
enum ScanEngine {
  portraitOcr;

  String get storageKey => name;

  String get displayName => switch (this) {
        ScanEngine.portraitOcr => 'Portrait label OCR',
      };

  String get subtitle => switch (this) {
        ScanEngine.portraitOcr =>
          'Reads team code and slot number from printed portrait labels.',
      };

  List<String> get detailBullets => switch (this) {
        ScanEngine.portraitOcr => const [
              'Camera frames are analyzed with on-device text recognition.',
              'Empty slots print the team code and number (e.g. MEX 4) in the placeholder.',
              'The scanner locks to your team page and filters matches to that team.',
              'Confirmed missing stickers are saved to your collection automatically.',
            ],
      };

  static ScanEngine fromStorage(String? raw) {
    // Live scan always uses portrait OCR; legacy prefs are ignored.
    return ScanEngine.portraitOcr;
  }
}
