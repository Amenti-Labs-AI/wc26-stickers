import 'package:flutter/services.dart';

import 'sticker_code_parser.dart';

enum StickerSearchKind { none, teamCode, exactCode }

/// Limits collection search to [maxLength] chars; when full, new input replaces the field.
class TeamCodeSearchFormatter extends TextInputFormatter {
  const TeamCodeSearchFormatter({this.maxLength = 3});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase();

    if (oldValue.text.length >= maxLength && text.length > maxLength) {
      var overflow = text.substring(maxLength);
      if (overflow.length > maxLength) {
        overflow = overflow.substring(overflow.length - maxLength);
      }
      return TextEditingValue(
        text: overflow,
        selection: TextSelection.collapsed(offset: overflow.length),
      );
    }

    if (text.length > maxLength) {
      final trimmed = text.substring(0, maxLength);
      return TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }

    return TextEditingValue(
      text: text,
      selection: newValue.selection,
    );
  }
}

/// Parsed collection search: team code only, or exact sticker code.
class StickerSearchQuery {
  const StickerSearchQuery._({required this.kind, this.teamCode, this.code});

  const StickerSearchQuery.none() : this._(kind: StickerSearchKind.none);

  const StickerSearchQuery.teamCode(String team)
      : this._(kind: StickerSearchKind.teamCode, teamCode: team);

  const StickerSearchQuery.exactCode(String stickerCode)
      : this._(kind: StickerSearchKind.exactCode, code: stickerCode);

  final StickerSearchKind kind;
  final String? teamCode;
  final String? code;

  /// Returns [StickerSearchQuery.none] for empty or unrecognised input.
  static StickerSearchQuery parse(String? raw) {
    if (raw == null) return const StickerSearchQuery.none();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const StickerSearchQuery.none();

    final compact = trimmed.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    final spaced = trimmed.toUpperCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();

    final fromParser = StickerCodeParser.parse(spaced);
    if (fromParser != null) {
      return StickerSearchQuery.exactCode(fromParser);
    }

    // Team-only: 3-letter codes, or 2-letter CC specials.
    if (RegExp(r'^[A-Z]{3}$').hasMatch(compact)) {
      return StickerSearchQuery.teamCode(compact);
    }
    if (compact == 'CC') {
      return StickerSearchQuery.teamCode(compact);
    }

    return const StickerSearchQuery.none();
  }
}
