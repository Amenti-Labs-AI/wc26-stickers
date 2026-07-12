import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/features/scan_page/live_overlay_tracker.dart';
import 'package:panini_wc26_tracker/features/scan_page/slot_overlay_painter.dart';

MissingSlotOverlay _slot(
  String code, {
  double x = 0.1,
  double y = 0.2,
  double w = 0.18,
  double h = 0.28,
}) =>
    MissingSlotOverlay(
      code: code,
      displayName: code,
      slotNumber: 1,
      x: x,
      y: y,
      w: w,
      h: h,
    );

void main() {
  group('LiveOverlayTracker', () {
    test('requires consecutive hits before first display', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 2);

      expect(tracker.update([_slot('MEX4')]), isEmpty);
      final second = tracker.update([_slot('MEX4')]);
      expect(second, hasLength(1));
      expect(second.first.code, 'MEX4');
    });

    test('holds overlays when a frame returns nothing', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1);

      tracker.update([
        _slot('MEX4', x: 0.10),
        _slot('MEX5', x: 0.40),
      ]);
      final held = tracker.update(const []);

      expect(held.map((o) => o.code), ['MEX4', 'MEX5']);
    });

    test('smooths position changes instead of jumping', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1, positionBlend: 0.5);

      tracker.update([_slot('MEX4', x: 0.10)]);
      final blended = tracker.update([_slot('MEX4', x: 0.30)]);

      expect(blended.first.x, closeTo(0.20, 0.001));
    });

    test('clears held overlays when detections are a different page', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1);

      tracker.update([
        _slot('MEX4', x: 0.10),
        _slot('MEX5', x: 0.40),
      ]);
      expect(
        tracker.isPageChange([
          _slot('MEX10', x: 0.10),
          _slot('MEX11', x: 0.40),
        ]),
        isTrue,
      );

      final nextPage = tracker.update([
        _slot('MEX10', x: 0.10),
        _slot('MEX11', x: 0.40),
      ]);
      expect(nextPage.map((o) => o.code), ['MEX10', 'MEX11']);
    });

    test('does not treat empty frames as a page change', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1);

      tracker.update([
        _slot('MEX4', x: 0.10),
        _slot('MEX5', x: 0.40),
      ]);
      expect(tracker.isPageChange(const []), isFalse);
      expect(tracker.update(const []).map((o) => o.code), ['MEX4', 'MEX5']);
    });

    test('does not treat a single mismatched detection as a page change', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1);

      tracker.update([
        _slot('MEX4', x: 0.10),
        _slot('MEX5', x: 0.40),
        _slot('MEX6', x: 0.70),
      ]);
      expect(tracker.isPageChange([_slot('MEX99', x: 0.10)]), isFalse);
    });

    test('keeps briefly-missed codes when new frame still shares a code', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1);

      tracker.update([
        _slot('MEX4', x: 0.10),
        _slot('MEX5', x: 0.40),
      ]);
      expect(
        tracker.isPageChange([
          _slot('MEX5', x: 0.40),
          _slot('MEX6', x: 0.70),
        ]),
        isFalse,
      );

      final partial = tracker.update([
        _slot('MEX5', x: 0.40),
        _slot('MEX6', x: 0.70),
      ]);
      expect(partial.map((o) => o.code), containsAll(['MEX4', 'MEX5', 'MEX6']));
    });

    test('keeps all four neighbors even when boxes overlap spatially', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1);

      final held = tracker.update([
        _slot('MEX4', x: 0.10, y: 0.20, w: 0.20, h: 0.28),
        _slot('MEX5', x: 0.22, y: 0.20, w: 0.20, h: 0.28),
        _slot('MEX6', x: 0.10, y: 0.40, w: 0.20, h: 0.28),
        _slot('MEX7', x: 0.22, y: 0.40, w: 0.20, h: 0.28),
      ]);
      expect(held.map((o) => o.code), ['MEX4', 'MEX5', 'MEX6', 'MEX7']);
    });

    test('drops missed codes after miss grace on non-empty frames', () async {
      final tracker = LiveOverlayTracker(
        minFramesToAdd: 1,
        missGraceDuration: const Duration(milliseconds: 40),
      );

      tracker.update([
        _slot('MEX4', x: 0.10),
        _slot('MEX5', x: 0.40),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final next = tracker.update([
        _slot('MEX5', x: 0.40),
        _slot('MEX6', x: 0.70),
      ]);
      expect(next.map((o) => o.code), ['MEX5', 'MEX6']);
    });
  });
}
