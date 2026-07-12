import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/missing_stickers_codec.dart';
import 'package:panini_wc26_tracker/data/database/app_database.dart';
import 'package:panini_wc26_tracker/data/models/collection_start_mode.dart';

void main() {
  const needJson = '''
{
  "version": 1,
  "type": "missing_stickers",
  "exported_at": "2026-06-15T12:00:00.000Z",
  "codes": ["MEX4", "MEX5"]
}
''';

  const collectionJson = '''
{
  "version": 1,
  "type": "collection_backup",
  "exported_at": "2026-07-11T12:00:00.000Z",
  "start_mode": "owned_scan",
  "collection": [
    {"code": "MEX1", "owned_count": 1},
    {"code": "MEX2", "owned_count": 3},
    {"code": "ARG1", "owned_count": 0}
  ],
  "scanned_missing": ["ARG1"],
  "parallels": [
    {"code": "MEX1", "kind": "blue", "count": 2}
  ]
}
''';

  group('CollectionStartMode', () {
    test('storage round-trip', () {
      for (final mode in CollectionStartMode.values) {
        expect(
          CollectionStartMode.fromStorageKey(mode.storageKey),
          mode,
        );
      }
      expect(CollectionStartMode.fromStorageKey(null), isNull);
      expect(CollectionStartMode.fromStorageKey('nope'), isNull);
    });

    test('owned_scan maps to owned count 1; all_missing to 0', () {
      expect(CollectionStartMode.ownedScan.storageKey, 'owned_scan');
      expect(CollectionStartMode.allMissing.storageKey, 'all_missing');
    });
  });

  group('MissingStickersCodec (legacy)', () {
    test('encode/decode round-trip preserves payload', () {
      final encoded = encodeMissingStickers(needJson);
      expect(encoded.startsWith(missingStickersBackupPrefix), isTrue);

      final decoded = decodeMissingStickers(encoded);
      final original = jsonDecode(needJson) as Map<String, dynamic>;
      final restored = jsonDecode(decoded) as Map<String, dynamic>;
      expect(restored['type'], original['type']);
      expect(restored['codes'], original['codes']);
    });

    test('decode accepts raw JSON', () {
      final decoded = decodeMissingStickers(needJson);
      expect(jsonDecode(decoded)['codes'], ['MEX4', 'MEX5']);
    });

    test('decode accepts quoted backup code', () {
      final encoded = encodeMissingStickers(needJson);
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

    test('decodeMissingStickers rejects full collection backup', () {
      expect(
        () => decodeMissingStickers(collectionJson),
        throwsFormatException,
      );
    });
  });

  group('Collection backup codec', () {
    test('encode/decode round-trip uses gzip prefix', () {
      final encoded = encodeCollectionBackup(collectionJson);
      expect(encoded.startsWith(collectionBackupPrefix), isTrue);
      expect(encoded.startsWith(collectionBackupPrefixLegacy), isFalse);

      final decoded = decodeBackupPayload(encoded);
      final restored = jsonDecode(decoded) as Map<String, dynamic>;
      expect(restored['type'], AppDatabase.collectionBackupExportType);
      expect(restored['start_mode'], 'owned_scan');
      expect(restored['scanned_missing'], ['ARG1']);
      expect((restored['collection'] as List).length, 3);
      expect((restored['parallels'] as List).length, 1);
    });

    test('gzip payload is smaller than plain base64 for typical JSON', () {
      final gzipped = encodeCollectionBackup(collectionJson);
      final plainMinified = jsonEncode(jsonDecode(collectionJson));
      final plainB64Len = base64Url.encode(utf8.encode(plainMinified)).length;
      // Payload after prefix
      final gzipPayloadLen =
          gzipped.length - collectionBackupPrefix.length;
      expect(gzipPayloadLen, lessThan(plainB64Len));
    });

    test('still decodes legacy uncompressed wc26:c1: codes', () {
      final minified = jsonEncode(jsonDecode(collectionJson));
      final legacy = '$collectionBackupPrefixLegacy'
          '${base64Url.encode(utf8.encode(minified)).replaceAll('=', '')}';
      final decoded = decodeBackupPayload(legacy);
      expect(isCollectionBackupJson(decoded), isTrue);
      expect(jsonDecode(decoded)['scanned_missing'], ['ARG1']);
    });

    test('decodeBackupPayload accepts raw collection JSON', () {
      final decoded = decodeBackupPayload(collectionJson);
      expect(isCollectionBackupJson(decoded), isTrue);
    });

    test('decodeBackupPayload accepts legacy need prefix', () {
      final encoded = encodeMissingStickers(needJson);
      final decoded = decodeBackupPayload(encoded);
      expect(isCollectionBackupJson(decoded), isFalse);
      expect(jsonDecode(decoded)['codes'], ['MEX4', 'MEX5']);
    });

    test('importCollectionBackupJson rejects wrong type before DB', () {
      expect(
        () => AppDatabase.instance.importCollectionBackupJson(needJson),
        throwsFormatException,
      );
    });

    test('importMissingStickersJson rejects collection backup type', () {
      expect(
        () => AppDatabase.instance.importMissingStickersJson(collectionJson),
        throwsFormatException,
      );
    });
  });
}
