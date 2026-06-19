import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/missing_stickers_codec.dart';
import 'package:panini_wc26_tracker/data/database/app_database.dart';

void main() {
  const sampleJson = '''
{
  "version": 1,
  "type": "missing_stickers",
  "exported_at": "2026-06-15T12:00:00.000Z",
  "codes": ["MEX4", "MEX5"]
}
''';

  group('MissingStickersCodec', () {
    test('encode/decode round-trip preserves payload', () {
      final encoded = encodeMissingStickers(sampleJson);
      expect(encoded.startsWith(missingStickersBackupPrefix), isTrue);

      final decoded = decodeMissingStickers(encoded);
      final original = jsonDecode(sampleJson) as Map<String, dynamic>;
      final restored = jsonDecode(decoded) as Map<String, dynamic>;
      expect(restored['type'], original['type']);
      expect(restored['codes'], original['codes']);
    });

    test('decode accepts raw JSON', () {
      final decoded = decodeMissingStickers(sampleJson);
      expect(jsonDecode(decoded)['codes'], ['MEX4', 'MEX5']);
    });

    test('decode accepts quoted backup code', () {
      final encoded = encodeMissingStickers(sampleJson);
      final decoded = decodeMissingStickers('"$encoded"');
      expect(jsonDecode(decoded)['codes'], ['MEX4', 'MEX5']);
    });

    test('rejects unknown prefix', () {
      expect(
        () => decodeMissingStickers('wc27:1:abc'),
        throwsFormatException,
      );
    });

    test('rejects garbage payload', () {
      expect(
        () => decodeMissingStickers('wc26:1:!!!'),
        throwsFormatException,
      );
    });
  });

  group('missing stickers JSON import', () {
    test('missing stickers JSON round-trips type and codes', () async {
      final data = jsonDecode(sampleJson) as Map<String, dynamic>;
      expect(data['type'], AppDatabase.missingStickersExportType);
      expect(data['codes'], ['MEX4', 'MEX5']);
    });

    test('encoded backup imports via decode + importMissingStickersJson', () async {
      final encoded = encodeMissingStickers(sampleJson);
      final json = decodeMissingStickers(encoded);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['type'], AppDatabase.missingStickersExportType);
      expect(data['codes'], ['MEX4', 'MEX5']);
    });

    test('import rejects unknown export type', () async {
      const jsonStr = '{"version": 1, "type": "album_backup", "codes": []}';
      expect(
        () => AppDatabase.instance.importMissingStickersJson(jsonStr),
        throwsFormatException,
      );
      expect(
        () => decodeMissingStickers(jsonStr),
        throwsFormatException,
      );
    });

    test('import rejects missing codes array', () async {
      const jsonStr = '{"version": 1, "type": "missing_stickers"}';
      expect(
        () => AppDatabase.instance.importMissingStickersJson(jsonStr),
        throwsFormatException,
      );
      expect(
        () => decodeMissingStickers(jsonStr),
        throwsFormatException,
      );
    });
  });
}
