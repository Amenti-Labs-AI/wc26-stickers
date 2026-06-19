/// Common ML Kit misreads for stylized album team codes.
const teamCodeOcrAliases = <String, String>{
  'OAT': 'QAT',
  '0AT': 'QAT',
  'GAT': 'QAT',
  'QOT': 'QAT',
  'Q0T': 'QAT',
  'QAF': 'QAT',
  'IRO': 'IRQ',
  'IR0': 'IRQ',
  'IRG': 'IRQ',
  'IRC': 'IRQ',
};

/// Normalizes a single OCR token to a catalog team code when possible.
String? resolveOcrTeamToken(String raw, Set<String> knownTeamCodes) {
  final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (cleaned.isEmpty) return null;

  var team = teamCodeOcrAliases[cleaned] ?? cleaned;
  if (team.length < 2 || team.length > 3) return null;
  if (!RegExp(r'^[A-Z0-9]{2,3}$').hasMatch(team)) return null;

  if (team == 'AT' && knownTeamCodes.contains('QAT')) {
    team = 'QAT';
  }
  if (team == 'IR' && knownTeamCodes.contains('IRQ')) {
    team = 'IRQ';
  }
  if (team == 'FW' && knownTeamCodes.contains('FWC')) {
    team = 'FWC';
  }
  if (knownTeamCodes.isNotEmpty && !knownTeamCodes.contains(team)) {
    return null;
  }
  return team;
}

/// Rewrites common team misreads inside a line before sticker parsing.
String normalizeTeamTextForParse(String text) {
  var upper = text.toUpperCase();
  for (final entry in teamCodeOcrAliases.entries) {
    upper = upper.replaceAll(
      RegExp('\\b${RegExp.escape(entry.key)}\\b'),
      entry.value,
    );
    upper = upper.replaceFirstMapped(
      RegExp('^${RegExp.escape(entry.key)}(\\d{1,2})'),
      (match) => '${entry.value}${match.group(1)}',
    );
  }
  return upper;
}

/// Fixes parsed catalog codes after regex extraction (e.g. OAT8 → QAT8).
String normalizeParsedStickerCode(String code) {
  for (final entry in teamCodeOcrAliases.entries) {
    if (code.startsWith(entry.key) && code.length > entry.key.length) {
      return entry.value + code.substring(entry.key.length);
    }
  }
  if (code.startsWith('AT') && code.length > 2) {
    return 'QAT${code.substring(2)}';
  }
  if (code.startsWith('IR') && !code.startsWith('IRQ') && code.length > 2) {
    return 'IRQ${code.substring(2)}';
  }
  return code;
}
