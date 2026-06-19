import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../core/camera_frame_codec.dart';
import 'ocr_label_rescue.dart';
import 'ocr_live_frame.dart';
import 'ocr_speed.dart';
import 'ocr_text_line.dart';
import 'page_scan_service.dart';
import 'portrait_text_matcher.dart';
import 'template_ocr.dart';

/// OCR-only missing-slot detection from portrait label text (team + number).
class PortraitOcrScanResult {
  const PortraitOcrScanResult({
    this.teamCode,
    this.missingCodes = const {},
    this.matches = const [],
    this.lineCount = 0,
    this.analysisWidth = 0,
    this.analysisHeight = 0,
    this.teamSwitched = false,
    this.debug = '',
  });

  final String? teamCode;
  final Set<String> missingCodes;
  final List<PortraitTextMatch> matches;
  final int lineCount;
  final int analysisWidth;
  final int analysisHeight;
  final bool teamSwitched;
  final String debug;
}

class PortraitOcrScanner {
  PortraitOcrScanner({
    required TextRecognizer recognizer,
    List<PageTemplate> templates = const [],
    PortraitTextMatcher? matcher,
    PortraitTextMatcher? cropMatcher,
  })  : _recognizer = recognizer,
        _knownTeamCodes = templates.map((t) => t.teamCode.toUpperCase()).toSet(),
        _catalogCodesByTeam = {
          for (final template in templates)
            template.teamCode.toUpperCase(): {
              for (final slot in template.slots) slot.stickerCode,
            },
        },
        _matcher = matcher ?? PortraitTextMatcher(),
        _cropMatcher = cropMatcher ??
            PortraitTextMatcher(
              maxVerticalGap: 0.14,
              maxHorizontalDrift: 0.32,
            );

  final TextRecognizer _recognizer;
  final Set<String> _knownTeamCodes;
  final Map<String, Set<String>> _catalogCodesByTeam;
  final PortraitTextMatcher _matcher;
  final PortraitTextMatcher _cropMatcher;

  /// Live camera path — OCR from raw frame bytes when possible (no RGB decode).
  Future<PortraitOcrScanResult> scanLivePayload(
    CameraFramePayload payload, {
    String? filterTeamCode,
  }) async {
    var lines = await ocrLiveCameraLines(_recognizer, payload);
    var analysisWidth = 0;
    var analysisHeight = 0;
    var path = 'fast';

    if (lines != null) {
      final dims = orientedAnalysisDimensions(payload);
      analysisWidth = dims.$1;
      analysisHeight = dims.$2;
    } else {
      path = 'decode';
      final decoded = await compute(decodeCameraFramePayload, payload);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return const PortraitOcrScanResult(debug: 'bad-frame');
      }
      lines = await ocrPageTextLines(
        _recognizer,
        decoded,
        speed: OcrSpeed.live,
      );
      analysisWidth = decoded.width;
      analysisHeight = decoded.height;
    }

    return _finishScan(
      lines: lines,
      speed: OcrSpeed.live,
      filterTeamCode: filterTeamCode,
      analysisWidth: analysisWidth,
      analysisHeight: analysisHeight,
      path: path,
    );
  }

  /// Reads empty-slot codes from printed portrait labels on [page].
  Future<PortraitOcrScanResult> scan(
    img.Image page, {
    OcrSpeed? speed,
    String? filterTeamCode,
  }) async {
    if (page.width <= 0 || page.height <= 0) {
      return const PortraitOcrScanResult(debug: 'bad-frame');
    }

    final resolvedSpeed = speed ?? speedForImage(page);
    final lines = await ocrPageTextLines(
      _recognizer,
      page,
      speed: resolvedSpeed,
    );

    return _finishScan(
      lines: lines,
      speed: resolvedSpeed,
      filterTeamCode: filterTeamCode,
      analysisWidth: page.width,
      analysisHeight: page.height,
      page: page,
      path: resolvedSpeed.name,
    );
  }

  Future<PortraitOcrScanResult> _finishScan({
    required List<OcrTextLine> lines,
    required OcrSpeed speed,
    required String? filterTeamCode,
    required int analysisWidth,
    required int analysisHeight,
    required String path,
    img.Image? page,
  }) async {
    final matcher = speed == OcrSpeed.crop ? _cropMatcher : _matcher;
    var matches = matcher.matchStackedTeamNumber(
      lines: lines,
      knownTeamCodes: _knownTeamCodes,
      filterTeamCode: filterTeamCode,
    );

    var rescued = 0;
    var workingLines = lines;
    if (speed != OcrSpeed.live && page != null) {
      final before = workingLines.length;
      workingLines = await rescueUnpairedTeamLabels(
        recognizer: _recognizer,
        page: page,
        matcher: matcher,
        lines: workingLines,
        matches: matches,
        knownTeamCodes: _knownTeamCodes,
        filterTeamCode: filterTeamCode,
      );
      rescued = workingLines.length - before;
      if (rescued > 0) {
        matches = matcher.matchStackedTeamNumber(
          lines: workingLines,
          knownTeamCodes: _knownTeamCodes,
          filterTeamCode: filterTeamCode,
        );
      }
    }

    matches = _dropInvalidMatches(matches, speed: speed);

    final codes = matches.map((m) => m.stickerCode).toSet();
    final team = matcher.inferTeamFromMatches(matches) ??
        filterTeamCode?.toUpperCase();

    return PortraitOcrScanResult(
      teamCode: team,
      missingCodes: codes,
      matches: matches,
      lineCount: workingLines.length,
      analysisWidth: analysisWidth,
      analysisHeight: analysisHeight,
      debug: 'team=$team codes=${codes.length} lines=${workingLines.length} '
          'speed=${speed.name} path=$path rescued=$rescued',
    );
  }

  List<PortraitTextMatch> _dropInvalidMatches(
    List<PortraitTextMatch> matches, {
    required OcrSpeed speed,
  }) {
    return [
      for (final match in matches)
        if (_isValidPortraitMatch(match, speed: speed)) match,
    ];
  }

  bool _isValidPortraitMatch(PortraitTextMatch match, {required OcrSpeed speed}) {
    // Full-page footer filter; zoom crops may legitimately fill the frame.
    if (speed != OcrSpeed.crop && match.readY >= 0.84) return false;

    final catalog = _catalogCodesByTeam[match.teamCode];
    if (catalog == null) return true;
    return catalog.contains(match.stickerCode);
  }

  @visibleForTesting
  static OcrSpeed speedForImage(img.Image page) {
    final maxDim = math.max(page.width, page.height);
    if (maxDim < 700) return OcrSpeed.crop;
    return OcrSpeed.standard;
  }
}
