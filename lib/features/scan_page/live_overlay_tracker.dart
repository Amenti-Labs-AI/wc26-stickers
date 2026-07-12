import 'ocr_overlay_builder.dart';
import 'slot_overlay_painter.dart';

/// Keeps overlays stable across noisy live OCR frames.
class LiveOverlayTracker {
  LiveOverlayTracker({
    /// How long to keep overlays when OCR returns nothing (camera between pages).
    this.emptyHoldDuration = const Duration(milliseconds: 1600),
    /// How long a code may stay after vanishing from a non-empty frame.
    /// Must cover several OCR misses (~450ms scan interval).
    this.missGraceDuration = const Duration(milliseconds: 2200),
    this.minFramesToAdd = 2,
    this.positionBlend = 0.4,
  });

  final Duration emptyHoldDuration;
  final Duration missGraceDuration;
  final int minFramesToAdd;
  final double positionBlend;

  final Map<String, _TrackedOverlay> _tracked = {};

  Set<String> get _stableCodes => {
        for (final entry in _tracked.entries)
          if (entry.value.stable || entry.value.hits >= minFramesToAdd)
            entry.key,
      };

  /// True when a confident new page is in view (no code overlap with held set).
  ///
  /// Requires at least two incoming detections so a single OCR misread cannot
  /// wipe a stable multi-slot page.
  bool isPageChange(List<MissingSlotOverlay> detected) {
    if (detected.length < 2) return false;
    final held = _stableCodes;
    if (held.isEmpty) return false;
    final incoming = {for (final o in detected) o.code};
    return held.intersection(incoming).isEmpty;
  }

  List<MissingSlotOverlay> update(List<MissingSlotOverlay> detected) {
    final now = DateTime.now();
    // Dedupe by code only for intake — spatial IoU must not drop neighbor slots.
    final uniqueDetected = OcrOverlayBuilder.uniqueByCode(detected);

    if (isPageChange(uniqueDetected)) {
      clear();
    }

    for (final overlay in uniqueDetected) {
      final existing = _tracked[overlay.code];
      if (existing == null) {
        _tracked[overlay.code] = _TrackedOverlay(
          overlay: overlay,
          hits: 1,
          lastSeen: now,
        );
        continue;
      }

      existing.hits++;
      existing.lastSeen = now;
      existing.overlay = _blend(existing.overlay, overlay);
      if (existing.hits >= minFramesToAdd) {
        existing.stable = true;
      }
    }

    final hold = uniqueDetected.isEmpty ? emptyHoldDuration : missGraceDuration;
    _tracked.removeWhere((_, track) => now.difference(track.lastSeen) > hold);

    final visible = <MissingSlotOverlay>[
      for (final track in _tracked.values)
        if (track.stable || track.hits >= minFramesToAdd) track.overlay,
    ];

    // Never spatial-cull held overlays — neighboring stickers often overlap IoU.
    return OcrOverlayBuilder.uniqueByCode(visible);
  }

  void clear() => _tracked.clear();

  MissingSlotOverlay _blend(
    MissingSlotOverlay previous,
    MissingSlotOverlay next,
  ) {
    final t = positionBlend.clamp(0.05, 1.0);
    double lerp(double a, double b) => a + (b - a) * t;

    return MissingSlotOverlay(
      code: next.code,
      displayName: next.displayName,
      slotNumber: next.slotNumber,
      scannedTeamCode: next.scannedTeamCode,
      x: lerp(previous.x, next.x),
      y: lerp(previous.y, next.y),
      w: lerp(previous.w, next.w),
      h: lerp(previous.h, next.h),
      readX: next.readX,
      readY: next.readY,
      readW: next.readW,
      readH: next.readH,
      state: next.state,
    );
  }
}

class _TrackedOverlay {
  _TrackedOverlay({
    required this.overlay,
    required this.hits,
    required this.lastSeen,
  });

  MissingSlotOverlay overlay;
  int hits;
  DateTime lastSeen;
  bool stable = false;
}
