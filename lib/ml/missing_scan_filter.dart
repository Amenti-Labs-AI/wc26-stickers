import 'portrait_text_matcher.dart';

const _catalogCodePattern = r'^[A-Z]{2,3}\d{1,2}$';

/// Catalog sticker codes confirmed missing on a live scan (OCR-validated).
List<String> confirmedMissingStickerCodes(Iterable<String> rawCodes) {
  final codes = <String>{};
  for (final raw in rawCodes) {
    final code = raw.toUpperCase();
    if (RegExp(_catalogCodePattern).hasMatch(code)) codes.add(code);
  }
  return codes.toList()..sort();
}

List<String> confirmedMissingCodes(Iterable<PortraitTextMatch> matches) =>
    confirmedMissingStickerCodes(matches.map((m) => m.stickerCode));

/// Keeps only matches for the locked team page being scanned.
List<PortraitTextMatch> filterMatchesToTeam(
  List<PortraitTextMatch> matches, {
  String? teamCode,
}) {
  if (teamCode == null) return matches;
  final team = teamCode.toUpperCase();
  return [for (final match in matches) if (match.teamCode == team) match];
}

/// Locks live scan to the dominant team once labels are read.
String? resolveActiveTeamCode({
  required String? currentTeam,
  required List<PortraitTextMatch> matches,
  required PortraitTextMatcher matcher,
}) {
  if (matches.isEmpty) return currentTeam;
  final inferred = matcher.inferTeamFromMatches(matches);
  if (inferred == null) return currentTeam;
  if (currentTeam == null) return inferred;
  if (currentTeam == inferred) return currentTeam;

  final currentCount =
      matches.where((m) => m.teamCode == currentTeam).length;
  final inferredCount =
      matches.where((m) => m.teamCode == inferred).length;

  // Page turned: locked team has no labels on this frame.
  if (currentCount == 0) return inferred;

  // New spread clearly dominates (e.g. turned from MEX to KOR).
  if (inferredCount > currentCount) return inferred;

  if (matches.every((m) => m.teamCode == inferred)) return inferred;
  return currentTeam;
}
