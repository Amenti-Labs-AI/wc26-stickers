import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/features/scan_page/live_overlay_tracker.dart';
import 'package:panini_wc26_tracker/features/scan_page/slot_overlay_painter.dart';

MissingSlotOverlay _slot(String code, {double x = 0.1}) => MissingSlotOverlay(
      code: code,
      displayName: code,
      slotNumber: 1,
      x: x,
      y: 0.2,
      w: 0.18,
      h: 0.28,
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

      tracker.update([_slot('MEX4'), _slot('MEX5')]);
      final held = tracker.update(const []);

      expect(held, hasLength(2));
    });

    test('smooths position changes instead of jumping', () {
      final tracker = LiveOverlayTracker(minFramesToAdd: 1, positionBlend: 0.5);

      tracker.update([_slot('MEX4', x: 0.10)]);
      final blended = tracker.update([_slot('MEX4', x: 0.30)]);

      expect(blended.first.x, closeTo(0.20, 0.001));
    });
  });
}
