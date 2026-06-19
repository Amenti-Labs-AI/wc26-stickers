import '../core/sticker_code_parser.dart';
import 'ocr_text_line.dart';
import 'portrait_slot_from_read.dart';
import 'team_code_ocr_aliases.dart';

/// A missing-slot label read as team code stacked above slot number.
class PortraitTextMatch {
  const PortraitTextMatch({
    required this.teamCode,
    required this.slotNumber,
    required this.stickerCode,
    required this.overlayX,
    required this.overlayY,
    required this.overlayW,
    required this.overlayH,
    required this.readX,
    required this.readY,
    required this.readW,
    required this.readH,
  });

  final String teamCode;
  final int slotNumber;
  final String stickerCode;
  final double overlayX;
  final double overlayY;
  final double overlayW;
  final double overlayH;
  final double readX;
  final double readY;
  final double readW;
  final double readH;
}

/// Pairs OCR team-code lines with number lines directly below (portrait labels).
class PortraitTextMatcher {
  PortraitTextMatcher({
    this.bodyMinY = 0.08,
    this.maxVerticalGap = 0.11,
    this.maxHorizontalDrift = 0.14,
    this.portraitOverlayW = 0.108,
    this.portraitOverlayH = 0.158,
    this.portraitCenterBelowFraction = 0.42,
  });

  final double bodyMinY;
  final double maxVerticalGap;
  final double maxHorizontalDrift;
  final double portraitOverlayW;
  final double portraitOverlayH;
  final double portraitCenterBelowFraction;

  static final _teamOnly = RegExp(r'^[A-Z]{2,3}$');
  static final _numberOnly = RegExp(r'^\d{1,2}$');
  static final _catalogCode = RegExp(r'^[A-Z]{2,3}\d{1,2}$');

  /// Match stacked team+number labels, then single-line catalog codes in the body.
  List<PortraitTextMatch> matchStackedTeamNumber({
    required List<OcrTextLine> lines,
    Set<String> knownTeamCodes = const {},
    String? filterTeamCode,
  }) {
    final body = lines.where((l) => l.centerY >= bodyMinY).toList();
    if (body.isEmpty) return const [];

    final teamFilter = filterTeamCode?.toUpperCase();
    final matches = <PortraitTextMatch>[];
    final usedNumbers = <OcrTextLine>{};
    final usedTeamLines = <OcrTextLine>{};

    final teamLines = body.where((l) {
      final team = _resolveTeamCode(l.normalizedText, knownTeamCodes);
      if (team == null) return false;
      if (teamFilter != null && team != teamFilter) return false;
      return true;
    }).toList();

    final numberLines =
        body.where((l) => _numberOnly.hasMatch(l.normalizedText)).toList();

    for (final gapLimit in [maxVerticalGap, maxVerticalGap * 1.6]) {
      for (final teamLine in teamLines) {
        if (usedTeamLines.contains(teamLine)) continue;

        OcrTextLine? bestNumber;
        var bestGap = double.infinity;

        for (final numLine in numberLines) {
          if (usedNumbers.contains(numLine)) continue;
          if (numLine.top < teamLine.bottom - 0.004) continue;
          final gap = numLine.top - teamLine.bottom;
          if (gap < -0.004 || gap > gapLimit) continue;
          final drift = (numLine.centerX - teamLine.centerX).abs();
          if (drift > maxHorizontalDrift) continue;
          if (gap < bestGap) {
            bestGap = gap;
            bestNumber = numLine;
          }
        }

        if (bestNumber == null) continue;
        _addStackedMatch(
          teamLine: teamLine,
          numberLine: bestNumber,
          knownTeamCodes: knownTeamCodes,
          matches: matches,
          usedNumbers: usedNumbers,
          usedTeamLines: usedTeamLines,
        );
      }
    }

    _matchHorizontalTeamNumber(
      teamLines: teamLines,
      numberLines: numberLines,
      knownTeamCodes: knownTeamCodes,
      matches: matches,
      usedNumbers: usedNumbers,
      usedTeamLines: usedTeamLines,
    );

    _matchSingleLineCodes(
      body: body,
      knownTeamCodes: knownTeamCodes,
      teamFilter: teamFilter,
      matches: matches,
      usedLines: {...usedNumbers, ...usedTeamLines},
    );

    if (teamFilter != null) {
      _matchOrphanNumbersForTeam(
        body: body,
        numberLines: numberLines,
        teamCode: teamFilter,
        knownTeamCodes: knownTeamCodes,
        matches: matches,
        usedNumbers: usedNumbers,
      );
    }

    matches.sort((a, b) {
      final y = a.overlayY.compareTo(b.overlayY);
      if (y != 0) return y;
      return a.overlayX.compareTo(b.overlayX);
    });
    return matches;
  }

  void _matchHorizontalTeamNumber({
    required List<OcrTextLine> teamLines,
    required List<OcrTextLine> numberLines,
    required Set<String> knownTeamCodes,
    required List<PortraitTextMatch> matches,
    required Set<OcrTextLine> usedNumbers,
    required Set<OcrTextLine> usedTeamLines,
  }) {
    const maxHorizontalGap = 0.10;
    const maxVerticalDrift = 0.07;

    for (final teamLine in teamLines) {
      if (usedTeamLines.contains(teamLine)) continue;

      OcrTextLine? bestNumber;
      var bestGap = double.infinity;

      for (final numLine in numberLines) {
        if (usedNumbers.contains(numLine)) continue;
        if (numLine.x < teamLine.right - 0.004) continue;
        final gap = numLine.x - teamLine.right;
        if (gap < -0.004 || gap > maxHorizontalGap) continue;
        final drift = (numLine.centerY - teamLine.centerY).abs();
        if (drift > maxVerticalDrift) continue;
        if (gap < bestGap) {
          bestGap = gap;
          bestNumber = numLine;
        }
      }

      if (bestNumber == null) continue;
      _addStackedMatch(
        teamLine: teamLine,
        numberLine: bestNumber,
        knownTeamCodes: knownTeamCodes,
        matches: matches,
        usedNumbers: usedNumbers,
        usedTeamLines: usedTeamLines,
      );
    }
  }

  void _addStackedMatch({
    required OcrTextLine teamLine,
    required OcrTextLine numberLine,
    required Set<String> knownTeamCodes,
    required List<PortraitTextMatch> matches,
    required Set<OcrTextLine> usedNumbers,
    required Set<OcrTextLine> usedTeamLines,
  }) {
    final team = _resolveTeamCode(teamLine.normalizedText, knownTeamCodes)!;
    final slotNum = int.parse(numberLine.normalizedText);
    final stickerCode = '$team$slotNum';
    if (!_catalogCode.hasMatch(stickerCode)) return;
    if (StickerCodeParser.parse(stickerCode) == null) return;
    if (matches.any((m) => m.stickerCode == stickerCode)) return;

    usedNumbers.add(numberLine);
    usedTeamLines.add(teamLine);
    final read = teamLine.mergeWith(numberLine);
    final portrait = _portraitOverlay(read, slotNumber: slotNum, teamCode: team);

    matches.add(
      PortraitTextMatch(
        teamCode: team,
        slotNumber: slotNum,
        stickerCode: stickerCode,
        overlayX: portrait.x,
        overlayY: portrait.y,
        overlayW: portrait.w,
        overlayH: portrait.h,
        readX: read.x,
        readY: read.y,
        readW: read.w,
        readH: read.h,
      ),
    );
  }

  void _matchSingleLineCodes({
    required List<OcrTextLine> body,
    required Set<String> knownTeamCodes,
    required String? teamFilter,
    required List<PortraitTextMatch> matches,
    required Set<OcrTextLine> usedLines,
  }) {
    for (final line in body) {
      if (usedLines.contains(line)) continue;
      final codes = StickerCodeParser.parseAll(line.text);
      if (codes.isEmpty) {
        final parsed = StickerCodeParser.parse(line.text);
        if (parsed != null) codes.add(parsed);
      }
      for (final parsed in codes) {
        final team = RegExp(r'^([A-Z]{2,3})').firstMatch(parsed)?.group(1);
        if (team == null) continue;
        if (knownTeamCodes.isNotEmpty && !knownTeamCodes.contains(team)) continue;
        if (teamFilter != null && team != teamFilter) continue;
        if (matches.any((m) => m.stickerCode == parsed)) continue;

        final slotNum = int.tryParse(parsed.substring(team.length));
        if (slotNum == null) continue;

        final portrait = _portraitOverlay(
          line,
          slotNumber: slotNum,
          teamCode: team,
        );
        matches.add(
          PortraitTextMatch(
            teamCode: team,
            slotNumber: slotNum,
            stickerCode: parsed,
            overlayX: portrait.x,
            overlayY: portrait.y,
            overlayW: portrait.w,
            overlayH: portrait.h,
            readX: line.x,
            readY: line.y,
            readW: line.w,
            readH: line.h,
          ),
        );
      }
    }
  }

  void _matchOrphanNumbersForTeam({
    required List<OcrTextLine> body,
    required List<OcrTextLine> numberLines,
    required String teamCode,
    required Set<String> knownTeamCodes,
    required List<PortraitTextMatch> matches,
    required Set<OcrTextLine> usedNumbers,
  }) {
    final team = teamCode.toUpperCase();
    for (final numLine in numberLines) {
      if (usedNumbers.contains(numLine)) continue;
      if (_numberPairedWithOtherTeam(
        numLine: numLine,
        body: body,
        teamFilter: team,
        knownTeamCodes: knownTeamCodes,
      )) {
        continue;
      }
      final code = StickerCodeParser.parseWithTeamHint(numLine.text, team);
      if (code == null || !code.startsWith(team)) continue;
      if (matches.any((m) => m.stickerCode == code)) continue;

      final slotNum = int.tryParse(code.substring(team.length));
      if (slotNum == null) continue;

      usedNumbers.add(numLine);
      final portrait = _portraitOverlay(
        numLine,
        slotNumber: slotNum,
        teamCode: team,
      );
      matches.add(
        PortraitTextMatch(
          teamCode: team,
          slotNumber: slotNum,
          stickerCode: code,
          overlayX: portrait.x,
          overlayY: portrait.y,
          overlayW: portrait.w,
          overlayH: portrait.h,
          readX: numLine.x,
          readY: numLine.y,
          readW: numLine.w,
          readH: numLine.h,
        ),
      );
    }
  }

  bool _numberPairedWithOtherTeam({
    required OcrTextLine numLine,
    required List<OcrTextLine> body,
    required String teamFilter,
    required Set<String> knownTeamCodes,
  }) {
    for (final teamLine in body) {
      final other = _resolveTeamCode(teamLine.normalizedText, knownTeamCodes);
      if (other == null || other == teamFilter) continue;
      if (numLine.top < teamLine.bottom - 0.004) continue;
      final gap = numLine.top - teamLine.bottom;
      if (gap < -0.004 || gap > maxVerticalGap * 1.6) continue;
      final drift = (numLine.centerX - teamLine.centerX).abs();
      if (drift > maxHorizontalDrift) continue;
      return true;
    }
    return false;
  }

  /// Team-code lines in the body that were not paired into a [PortraitTextMatch].
  List<OcrTextLine> findUnpairedTeamLines({
    required List<OcrTextLine> lines,
    required List<PortraitTextMatch> matches,
    Set<String> knownTeamCodes = const {},
    String? filterTeamCode,
  }) {
    final body = lines.where((l) => l.centerY >= bodyMinY).toList();
    final teamFilter = filterTeamCode?.toUpperCase();

    final teamLines = body.where((l) {
      final team = _resolveTeamCode(l.normalizedText, knownTeamCodes);
      if (team == null) return false;
      if (teamFilter != null && team != teamFilter) return false;
      return true;
    }).toList();

    return [
      for (final teamLine in teamLines)
        if (!_teamLinePairedInMatch(teamLine, matches)) teamLine,
    ];
  }

  bool _teamLinePairedInMatch(OcrTextLine teamLine, List<PortraitTextMatch> matches) {
    final cx = teamLine.centerX;
    final cy = teamLine.centerY;
    for (final match in matches) {
      if (cx >= match.readX &&
          cx <= match.readX + match.readW &&
          cy >= match.readY &&
          cy <= match.readY + match.readH) {
        return true;
      }
    }
    return false;
  }

  /// OCR often misreads stylized team tokens (e.g. QAT → OAT, IRQ → IRO).
  String? _resolveTeamCode(String raw, Set<String> knownTeamCodes) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isEmpty) return null;
    return resolveOcrTeamToken(cleaned, knownTeamCodes);
  }

  /// @deprecated Use [matchStackedTeamNumber].
  List<PortraitTextMatch> findPortraitLabels({
    required List<OcrTextLine> lines,
    String? teamCode,
    Set<String> knownTeamCodes = const {},
  }) =>
      matchStackedTeamNumber(
        lines: lines,
        knownTeamCodes: knownTeamCodes,
        filterTeamCode: teamCode,
      );

  String? inferTeamFromMatches(List<PortraitTextMatch> matches) {
    if (matches.isEmpty) return null;
    final counts = <String, int>{};
    for (final m in matches) {
      counts[m.teamCode] = (counts[m.teamCode] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  ({double x, double y, double w, double h}) _portraitOverlay(
    OcrTextLine read, {
    int slotNumber = 0,
    String teamCode = '',
  }) {
    final slot = portraitSlotFromReadRect(
      readX: read.x,
      readY: read.y,
      readW: read.w,
      readH: read.h,
      slotNumber: slotNumber,
      stickerCode: teamCode.isEmpty ? '' : '$teamCode$slotNumber',
    );
    return (x: slot.x, y: slot.y, w: slot.w, h: slot.h);
  }
}
