import '../ml/team_code_ocr_aliases.dart';

/// Parses Panini sticker codes from OCR text (e.g. "BRA 14", "FWC0", "CAN3").
class StickerCodeParser {
  static final _patterns = [
    RegExp(r'\b([A-Z]{2,3})\s*(\d{1,2})(?!\d)'),
    RegExp(r'\b([A-Z]{2,3})(\d{1,2})(?!\d)'),
    RegExp(r'\b(FWC)\s*(\d{1,2})\b', caseSensitive: false),
    RegExp(r'\b(CC)\s*(\d{1,2})\b', caseSensitive: false),
  ];

  /// Returns normalized code like BRA14, FWC0, CC1 or null.
  static String? parse(String text) {
    final upper = normalizeTeamTextForParse(
      text.toUpperCase().replaceAll(RegExp(r'[^\w\s]'), ' '),
    );
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(upper);
      if (match != null) {
        var code = '${match.group(1)}${match.group(2)}';
        if (code.startsWith('FW') && !code.startsWith('FWC')) continue;
        code = normalizeParsedStickerCode(code);
        return code;
      }
    }
    return null;
  }

  /// Parse when team is known from page header (e.g. "14" → USA14).
  /// Ignores OCR fragments from FIFA branding (FW/FWC) on team pages.
  static String? parseWithTeamHint(String text, String teamCode) {
    final team = teamCode.toUpperCase();
    var cleaned = normalizeTeamTextForParse(
      text.toUpperCase().replaceAll(RegExp(r'[^\w\s]'), ' '),
    );

    if (team != 'FWC') {
      cleaned = cleaned.replaceAll(RegExp(r'\bFWC?\b'), ' ');
    }

    final fromFull = parse(cleaned);
    if (fromFull != null && fromFull.startsWith(team)) return fromFull;

    final digits = RegExp(r'\b(\d{1,2})\b').firstMatch(cleaned);
    if (digits == null) return null;
    return '$team${digits.group(1)}';
  }

  /// Extract all unique codes from a block of OCR text.
  static List<String> parseAll(String text) {
    final upper = normalizeTeamTextForParse(text.toUpperCase());
    final found = <String>{};
    for (final pattern in _patterns) {
      for (final match in pattern.allMatches(upper)) {
        found.add(
          normalizeParsedStickerCode('${match.group(1)}${match.group(2)}'),
        );
      }
    }
    return found.toList()..sort();
  }
}
