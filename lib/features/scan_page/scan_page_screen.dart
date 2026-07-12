import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/camera_frame_codec.dart';
import '../../core/camera_unavailable_screen.dart';
import '../../core/mobile_only_screen.dart';
import '../../core/platform.dart';
import '../../core/app_widgets.dart';
import '../../core/scan_wakelock.dart';
import '../../data/database/app_database.dart';
import '../../ml/missing_scan_filter.dart';
import '../../ml/page_scan_service.dart';
import '../collection/collection_providers.dart';
import 'camera_preview_mapper.dart';
import 'live_overlay_tracker.dart';
import 'ocr_overlay_builder.dart';
import 'scan_page_session.dart';
import 'slot_overlay_layer.dart';
import 'slot_overlay_painter.dart';

/// Live camera scan — portrait-label OCR only.
class ScanPageScreen extends ConsumerStatefulWidget {
  const ScanPageScreen({super.key, this.active = false});

  final bool active;

  @override
  ConsumerState<ScanPageScreen> createState() => _ScanPageScreenState();
}

class _ScanPageScreenState extends ConsumerState<ScanPageScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  final _scanService = PageScanService();
  ScanPageSession? _session;

  String _status = 'Point camera at team page';
  String _debug = '';
  List<MissingSlotOverlay> _overlays = const [];
  Size? _analysisImageSize;
  final _overlayTracker = LiveOverlayTracker(minFramesToAdd: 1);
  bool _scanInFlight = false;
  bool _ready = false;
  String? _cameraError;
  DateTime? _lastScanStartedAt;
  CameraFramePayload? _pendingPayload;
  Set<String> _lastSavedCodes = const {};
  /// Codes already persisted/haptic'd this Scan session (survives page turns).
  Set<String> _sessionSavedCodes = {};
  /// Owned sticker codes that are not Need — yellow discrepancy overlay only.
  Set<String> _ownedNotNeedCodes = {};

  /// Idle throttle between scans; backlog drains immediately after each OCR.
  static const _scanInterval = Duration(milliseconds: 450);
  static const _liveMaxEdgeOcr = 640;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareSession());
    if (widget.active) {
      unawaited(_setScanWakelock(true));
      unawaited(_startCamera());
    }
  }

  @override
  void didUpdateWidget(covariant ScanPageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      unawaited(_setScanWakelock(true));
      unawaited(_refreshOwnedCodes());
      unawaited(_startCamera());
    } else {
      _session?.resetTeamLock();
      _overlayTracker.clear();
      _lastSavedCodes = const {};
      _sessionSavedCodes = {};
      _pendingPayload = null;
      _scanInFlight = false;
      unawaited(_setScanWakelock(false));
      unawaited(_stopCamera());
    }
  }

  Future<void> _setScanWakelock(bool on) async {
    await ScanWakelock.toggle(enable: on);
  }

  Future<void> _prepareSession() async {
    if (mounted) {
      setState(() {
        _ready = false;
        _overlays = const [];
        _status = 'Starting scanner…';
        _debug = '';
      });
    }

    _session?.close();
    _session = null;

    await _scanService.initialize();
    final session = ScanPageSession(_scanService);
    await session.ensureReady();
    _session = session;
    await _refreshOwnedCodes();

    if (!mounted) return;
    setState(() {
      _ready = true;
      _status = 'Point camera at team page';
      _debug = '';
      _overlays = const [];
    });
  }

  Future<void> _startCamera() async {
    if (!isMobileScanSupported) return;
    await _setScanWakelock(true);
    if (_controller?.value.isInitialized ?? false) {
      await _ensureStream();
      return;
    }
    _cameraError = null;
    await _initCamera();
    if (mounted) setState(() {});
  }

  Future<void> _ensureStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;
    try {
      await controller.startImageStream(_onFrame);
    } catch (e) {
      _cameraError = 'Could not start camera stream: $e';
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopCamera() async {
    await _setScanWakelock(false);
    final controller = _controller;
    _controller = null;
    _camera = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _cameraError = 'No camera found.';
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camera = back;
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
    } catch (e) {
      _cameraError = 'Could not start camera: $e';
    }
  }

  void _onFrame(CameraImage image) {
    if (!widget.active) return;
    final camera = _camera;
    final session = _session;
    if (camera == null || session == null) return;

    final payload = CameraFramePayload.capture(
      image,
      camera,
      maxAnalysisEdge: _liveMaxEdgeOcr,
    );
    if (payload == null) return;
    _pendingPayload = payload;
    _scheduleScan(session);
  }

  void _scheduleScan(ScanPageSession session) {
    if (_scanInFlight || !widget.active || !mounted) return;

    final now = DateTime.now();
    if (_lastScanStartedAt != null &&
        now.difference(_lastScanStartedAt!) < _scanInterval) {
      return;
    }

    final payload = _pendingPayload;
    if (payload == null) return;

    _pendingPayload = null;
    _scanInFlight = true;
    _lastScanStartedAt = now;
    unawaited(_runScan(payload, session));
  }

  Future<void> _runScan(
    CameraFramePayload payload,
    ScanPageSession session,
  ) async {
    try {
      final result = await session.scanLivePayload(payload);
      if (!mounted || !widget.active) return;

      if (result.teamSwitched) {
        _overlayTracker.clear();
        _lastSavedCodes = const {};
        if (mounted) {
          setState(() => _overlays = const []);
        }
      }

      final analysisSize = result.analysisWidth > 0 && result.analysisHeight > 0
          ? Size(
              result.analysisWidth.toDouble(),
              result.analysisHeight.toDouble(),
            )
          : null;
      if (analysisSize == null) return;

      var overlays = OcrOverlayBuilder.build(matches: result.matches);
      final previewSize = _controller != null
          ? cameraPreviewImageSizeFromController(_controller!)
          : null;
      final overlayImageSize = previewSize ?? analysisSize;
      if (previewSize != null && previewSize != analysisSize) {
        overlays = OcrOverlayBuilder.remapToPreviewSpace(
          overlays: overlays,
          analysisImageSize: analysisSize,
          previewImageSize: previewSize,
        );
      }

      // Same-team page turn: held overlays share no codes with this frame.
      // Do not blank the UI here — tracker.update replaces held set atomically.
      if (_overlayTracker.isPageChange(overlays)) {
        _lastSavedCodes = const {};
      }

      final stableOverlays = _markOwnedOverlays(_overlayTracker.update(overlays));
      unawaited(_persistStableMissing(stableOverlays));

      final needCount = stableOverlays
          .where((o) => o.state != SlotOverlayState.alreadyOwned)
          .length;
      final ownedHitCount = stableOverlays.length - needCount;
      final needCodes = stableOverlays
          .where((o) => o.state != SlotOverlayState.alreadyOwned)
          .map((o) => o.code)
          .toList()
        ..sort();
      final status = stableOverlays.isEmpty
          ? 'Scanning for need stickers…'
          : [
              if (needCount > 0) '$needCount need · ${needCodes.join(' ')}',
              if (ownedHitCount > 0) '$ownedHitCount owned (check manually)',
            ].join(' · ');

      if (status == _status &&
          result.debug == _debug &&
          _sameOverlays(_overlays, stableOverlays) &&
          _analysisImageSize == overlayImageSize) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _status = status;
        _debug = result.debug;
        _overlays = stableOverlays;
        _analysisImageSize = overlayImageSize;
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('OCR scan failed: $e\n$st');
    } finally {
      _scanInFlight = false;
      if (mounted && widget.active) {
        if (_pendingPayload != null) {
          _lastScanStartedAt = null;
          _scheduleScan(session);
        }
      }
    }
  }

  Future<void> _refreshOwnedCodes() async {
    _ownedNotNeedCodes = await AppDatabase.instance.getOwnedNotNeedCodes();
  }

  List<MissingSlotOverlay> _markOwnedOverlays(
    List<MissingSlotOverlay> overlays,
  ) {
    if (overlays.isEmpty || _ownedNotNeedCodes.isEmpty) return overlays;
    return [
      for (final overlay in overlays)
        _ownedNotNeedCodes.contains(overlay.code.toUpperCase())
            ? overlay.copyWith(state: SlotOverlayState.alreadyOwned)
            : overlay.state == SlotOverlayState.alreadyOwned
                ? overlay.copyWith(state: SlotOverlayState.confirmed)
                : overlay,
    ];
  }

  Future<void> _persistStableMissing(
    List<MissingSlotOverlay> overlays, {
    List<String>? codes,
  }) async {
    final resolved = codes ??
        confirmedMissingStickerCodes(
          overlays
              .where((o) => o.state != SlotOverlayState.alreadyOwned)
              .map((o) => o.code),
        );
    if (resolved.isEmpty) return;

    final codeSet = resolved.toSet();
    final added = codeSet.difference(_sessionSavedCodes);
    if (added.isEmpty && setEquals(codeSet, _lastSavedCodes)) return;

    _lastSavedCodes = codeSet;
    _sessionSavedCodes = {..._sessionSavedCodes, ...codeSet};
    await _saveMissingCodes(resolved, haptic: added.isNotEmpty);
    // Newly saved needs are no longer "owned not need" discrepancy targets.
    if (added.isNotEmpty) {
      _ownedNotNeedCodes = _ownedNotNeedCodes.difference(added);
    }
  }

  Future<void> _saveMissingCodes(
    List<String> codes, {
    required bool haptic,
  }) async {
    await ref.read(collectionNotifierProvider.notifier).mergeScannedMissing(codes);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(scannedMissingByTeamProvider);
      ref.invalidate(swapsByTeamProvider);
      ref.invalidate(parallelsByTeamProvider);
      ref.invalidate(scannedMissingCodesProvider);
      ref.invalidate(groupedStickersProvider);
      ref.invalidate(collectionStatsProvider);
      ref.invalidate(stickersProvider);
    });
    if (haptic) {
      await HapticFeedback.lightImpact();
    }
  }

  bool _sameOverlays(List<MissingSlotOverlay> a, List<MissingSlotOverlay> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.code != right.code) return false;
      if (left.state != right.state) return false;
      if ((left.x - right.x).abs() > 0.01) return false;
      if ((left.y - right.y).abs() > 0.01) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _overlayTracker.clear();
    _lastSavedCodes = const {};
    _sessionSavedCodes = {};
    _pendingPayload = null;
    _scanInFlight = false;
    unawaited(_setScanWakelock(false));
    unawaited(_stopCamera());
    _session?.close();
    _scanService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isMobileScanSupported) {
      return const MobileOnlyScreen(feature: 'Album page scan');
    }
    if (!_ready || !widget.active) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cameraError != null) {
      return CameraUnavailableScreen(detail: _cameraError);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraCoverPreview(controller: controller),
        if (_overlays.isNotEmpty)
          SlotOverlayLayer(
            slots: _overlays,
            imageSize: _analysisImageSize,
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GlassPanel(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        kDebugMode ? '$_status · $_debug' : _status,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
