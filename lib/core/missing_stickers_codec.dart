import 'dart:convert';

import '../data/database/app_database.dart';

/// Wire prefix for shareable missing-list backup codes.
const missingStickersBackupPrefix = 'wc26:1:';

/// Encodes missing-list JSON as `wc26:1:<base64url(minified json)>`.
String encodeMissingStickers(String json) {
  final minified = jsonEncode(jsonDecode(json) as Object);
  final payload = base64Url
      .encode(utf8.encode(minified))
      .replaceAll('=', '');
  return '$missingStickersBackupPrefix$payload';
}

/// Decodes a backup code or raw JSON string into importable JSON.
String decodeMissingStickers(String input) {
  var trimmed = input.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
    trimmed = trimmed.substring(1, trimmed.length - 1).trim();
  }

  if (trimmed.startsWith('{')) {
    return _validateMissingStickersJson(trimmed);
  }

  if (!trimmed.startsWith(missingStickersBackupPrefix)) {
    throw FormatException(
      'Expected backup code starting with "$missingStickersBackupPrefix" or raw JSON',
    );
  }

  final payload = trimmed.substring(missingStickersBackupPrefix.length);
  if (payload.isEmpty) {
    throw const FormatException('Backup code payload is empty');
  }

  try {
    final padded = _padBase64Url(payload);
    final json = utf8.decode(base64Url.decode(padded));
    return _validateMissingStickersJson(json);
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

String _validateMissingStickersJson(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  final type = data['type'] as String?;
  if (type != AppDatabase.missingStickersExportType) {
    throw FormatException(
      'Expected type "${AppDatabase.missingStickersExportType}", got "$type"',
    );
  }
  final codes = data['codes'];
  if (codes is! List<dynamic>) {
    throw const FormatException('Missing or invalid "codes" array');
  }
  return jsonEncode(data);
}
