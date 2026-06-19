import 'slot_overlay_painter.dart';

/// Keeps overlays stable across noisy live OCR frames.
class LiveOverlayTracker {
  LiveOverlayTracker({
    this.holdDuration = const Duration(milliseconds: 2800),
    this.minFramesToAdd = 2,
    this.positionBlend = 0.4,
  });

  final Duration holdDuration;
  final int minFramesToAdd;
  final double positionBlend;

  final Map<String, _TrackedOverlay> _tracked = {};

  List<MissingSlotOverlay> update(List<MissingSlotOverlay> detected) {
    final now = DateTime.now();

    for (final overlay in detected) {
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

    _tracked.removeWhere(
      (_, track) => now.difference(track.lastSeen) > holdDuration,
    );

    final visible = <MissingSlotOverlay>[];
    for (final track in _tracked.values) {
      if (track.stable || track.hits >= minFramesToAdd) {
        visible.add(track.overlay);
      }
    }

    visible.sort((a, b) {
      final y = a.y.compareTo(b.y);
      if (y != 0) return y;
      return a.x.compareTo(b.x);
    });
    return visible;
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
