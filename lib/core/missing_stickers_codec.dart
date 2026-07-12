import 'dart:convert';
import 'dart:io';

import '../data/database/app_database.dart';

/// Wire prefix for need-list-only backup codes (legacy).
const missingStickersBackupPrefix = 'wc26:1:';

/// Full collection backup: gzip JSON, then Base64URL.
const collectionBackupPrefix = 'wc26:c2:';

/// Uncompressed full collection backup (pre-gzip exports).
const collectionBackupPrefixLegacy = 'wc26:c1:';

/// Encodes missing-list JSON as `wc26:1:<base64url(minified json)>`.
String encodeMissingStickers(String json) {
  final minified = jsonEncode(jsonDecode(json) as Object);
  return '$missingStickersBackupPrefix${_toBase64Url(utf8.encode(minified))}';
}

/// Encodes full collection JSON as `wc26:c2:<base64url(gzip(json))>`.
String encodeCollectionBackup(String json) {
  final minified = jsonEncode(jsonDecode(json) as Object);
  final compressed = gzip.encode(utf8.encode(minified));
  return '$collectionBackupPrefix${_toBase64Url(compressed)}';
}

String _toBase64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Decodes a backup code or raw JSON. Returns validated minified JSON.
///
/// Accepts:
/// - `wc26:c2:` gzip + Base64URL collection backup (current)
/// - `wc26:c1:` uncompressed Base64URL collection backup (legacy)
/// - `wc26:1:` need-list only
/// - raw JSON of either type
String decodeBackupPayload(String input) {
  var trimmed = input.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
    trimmed = trimmed.substring(1, trimmed.length - 1).trim();
  }

  if (trimmed.startsWith('{')) {
    return _validateBackupJson(trimmed);
  }

  if (trimmed.startsWith(collectionBackupPrefix)) {
    return _decodePrefixed(
      trimmed,
      collectionBackupPrefix,
      AppDatabase.collectionBackupExportType,
      gzipped: true,
    );
  }

  if (trimmed.startsWith(collectionBackupPrefixLegacy)) {
    return _decodePrefixed(
      trimmed,
      collectionBackupPrefixLegacy,
      AppDatabase.collectionBackupExportType,
      gzipped: false,
    );
  }

  if (trimmed.startsWith(missingStickersBackupPrefix)) {
    return _decodePrefixed(
      trimmed,
      missingStickersBackupPrefix,
      AppDatabase.missingStickersExportType,
      gzipped: false,
    );
  }

  throw const FormatException(
    'Expected backup code starting with "$collectionBackupPrefix", '
    '"$collectionBackupPrefixLegacy", or "$missingStickersBackupPrefix", '
    'or raw JSON',
  );
}

/// Legacy alias — need-list codes and raw need JSON only.
String decodeMissingStickers(String input) {
  final json = decodeBackupPayload(input);
  final data = jsonDecode(json) as Map<String, dynamic>;
  if (data['type'] != AppDatabase.missingStickersExportType) {
    throw FormatException(
      'Expected type "${AppDatabase.missingStickersExportType}", '
      'got "${data['type']}"',
    );
  }
  return json;
}

String _decodePrefixed(
  String trimmed,
  String prefix,
  String expectedType, {
  required bool gzipped,
}) {
  final payload = trimmed.substring(prefix.length);
  if (payload.isEmpty) {
    throw const FormatException('Backup code payload is empty');
  }

  try {
    final bytes = base64Url.decode(_padBase64Url(payload));
    final jsonBytes = gzipped ? gzip.decode(bytes) : bytes;
    final json = utf8.decode(jsonBytes);
    final validated = _validateBackupJson(json);
    final type = (jsonDecode(validated) as Map<String, dynamic>)['type'];
    if (type != expectedType) {
      throw FormatException('Expected type "$expectedType", got "$type"');
    }
    return validated;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid backup code encoding');
  }
}

String _padBase64Url(String payload) {
  final remainder = payload.length % 4;
  if (remainder == 0) return payload;
  return payload + ('=' * (4 - remainder));
}

String _validateBackupJson(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  final type = data['type'] as String?;
  if (type == AppDatabase.collectionBackupExportType) {
    if (data['collection'] is! List) {
      throw const FormatException('Missing or invalid "collection" array');
    }
    if (data['scanned_missing'] is! List) {
      throw const FormatException('Missing or invalid "scanned_missing" array');
    }
    if (data['parallels'] is! List) {
      throw const FormatException('Missing or invalid "parallels" array');
    }
    return jsonEncode(data);
  }
  if (type == AppDatabase.missingStickersExportType) {
    if (data['codes'] is! List) {
      throw const FormatException('Missing or invalid "codes" array');
    }
    return jsonEncode(data);
  }
  throw FormatException(
    'Expected type "${AppDatabase.collectionBackupExportType}" or '
    '"${AppDatabase.missingStickersExportType}", got "$type"',
  );
}

/// Whether [json] is a full collection backup (vs need-list only).
bool isCollectionBackupJson(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  return data['type'] == AppDatabase.collectionBackupExportType;
}
