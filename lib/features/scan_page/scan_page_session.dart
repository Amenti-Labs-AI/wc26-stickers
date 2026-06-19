import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/camera_frame_codec.dart';
import '../../ml/missing_scan_filter.dart';
import '../../ml/ocr_speed.dart';
import '../../ml/page_scan_service.dart';
import '../../ml/portrait_ocr_scanner.dart';
import '../../ml/portrait_text_matcher.dart';

/// Live-scan session — portrait-label OCR only (`docs/ml/strategy.md`).
class ScanPageSession {
  ScanPageSession(this.scanService);

  final PageScanService scanService;
  PortraitOcrScanner? _scanner;
  final PortraitTextMatcher _matcher = PortraitTextMatcher();
  String? _activeTeamCode;

  String? get activeTeamCode => _activeTeamCode;

  Future<void> ensureReady() async {
    await scanService.initialize();
    _scanner = PortraitOcrScanner(
      recognizer: scanService.matcher.textRecognizer,
      templates: scanService.templates,
    );
  }

  Future<PortraitOcrScanResult> scanLivePayload(CameraFramePayload payload) async {
    final scanner = _scanner;
    if (scanner == null) {
      return const PortraitOcrScanResult(debug: 'not-ready');
    }

    final raw = await scanner.scanLivePayload(payload);
    return _finalizeScan(
      raw: raw,
      analysisWidth: raw.analysisWidth,
      analysisHeight: raw.analysisHeight,
    );
  }

  /// Still-image scan with the same team lock + post-filter as live camera.
  Future<PortraitOcrScanResult> scanStillPage(
    img.Image page, {
    OcrSpeed speed = OcrSpeed.standard,
  }) async {
    final scanner = _scanner;
    if (scanner == null || page.width <= 0 || page.height <= 0) {
      return const PortraitOcrScanResult(debug: 'not-ready');
    }

    // Zoom crops only: hint team for orphan-number pairing. Full-page scans
    // match live camera — no pre-OCR team filter (page-turn must see all teams).
    final raw = await scanner.scan(
      page,
      speed: speed,
      filterTeamCode: speed == OcrSpeed.crop ? _activeTeamCode : null,
    );
    return _finalizeScan(
      raw: raw,
      analysisWidth: page.width,
      analysisHeight: page.height,
    );
  }

  Future<PortraitOcrScanResult> scanFrame(img.Image decoded) async {
    return scanStillPage(decoded, speed: OcrSpeed.live);
  }

  PortraitOcrScanResult _finalizeScan({
    required PortraitOcrScanResult raw,
    required int analysisWidth,
    required int analysisHeight,
  }) {
    final previousTeam = _activeTeamCode;
    _activeTeamCode = resolveActiveTeamCode(
      currentTeam: _activeTeamCode,
      matches: raw.matches,
      matcher: _matcher,
    );
    final teamSwitched = previousTeam != null &&
        _activeTeamCode != null &&
        previousTeam != _activeTeamCode;

    final matches = filterMatchesToTeam(
      raw.matches,
      teamCode: _activeTeamCode,
    );
    final codes = confirmedMissingCodes(matches).toSet();
    final team = _activeTeamCode ?? raw.teamCode;

    return PortraitOcrScanResult(
      teamCode: team,
      missingCodes: codes,
      matches: matches,
      lineCount: raw.lineCount,
      analysisWidth: analysisWidth,
      analysisHeight: analysisHeight,
      teamSwitched: teamSwitched,
      debug: '${raw.debug} lock=$team${teamSwitched ? ' switched' : ''}',
    );
  }

  void resetTeamLock() => _activeTeamCode = null;

  @visibleForTesting
  void lockTeam(String? code) => _activeTeamCode = code?.toUpperCase();

  /// Drop scanner state without closing [scanService] (tab pause).
  void close() {
    _scanner = null;
    _activeTeamCode = null;
  }

  /// Tear down session and owned [scanService] (tests and screen dispose).
  void dispose() {
    close();
    scanService.dispose();
  }
}
