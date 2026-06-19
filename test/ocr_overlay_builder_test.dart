import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/features/scan_page/camera_preview_mapper.dart';
import 'package:panini_wc26_tracker/features/scan_page/ocr_overlay_builder.dart';
import 'package:panini_wc26_tracker/features/scan_page/slot_overlay_painter.dart';
import 'package:panini_wc26_tracker/ml/ocr_text_line.dart';
import 'package:panini_wc26_tracker/ml/portrait_overlay_geometry.dart';
import 'package:panini_wc26_tracker/ml/portrait_text_matcher.dart';

void main() {
  group('portraitSlotFromOcrMatch', () {
    test('expands below OCR read cluster', () {
      const match = PortraitTextMatch(
        teamCode: 'MEX',
        slotNumber: 9,
        stickerCode: 'MEX9',
        overlayX: 0.55,
        overlayY: 0.62,
        overlayW: 0.108,
        overlayH: 0.158,
        readX: 0.60,
        readY: 0.66,
        readW: 0.06,
        readH: 0.04,
      );

      final slot = portraitSlotFromOcrMatch(match);
      expect(slot.w, greaterThan(match.readW));
      expect(slot.h, greaterThan(match.readH));
      expect(slot.w, closeTo(match.readW / 0.46, 0.02));
      expect(slot.h, closeTo(match.readH / 0.22, 0.02));
      expect(slot.y, lessThan(match.readY));
      expect(slot.x + slot.w / 2, closeTo(match.readX + match.readW / 2, 0.02));
    });
  });

  group('OcrOverlayBuilder', () {
    test('builds confirmed red overlays from matcher output', () {
      final matcher = PortraitTextMatcher();
      final matches = matcher.matchStackedTeamNumber(
        lines: [
          const OcrTextLine(text: 'MEX', x: 0.60, y: 0.66, w: 0.05, h: 0.02),
          const OcrTextLine(text: '9', x: 0.61, y: 0.685, w: 0.03, h: 0.02),
        ],
        knownTeamCodes: {'MEX'},
        filterTeamCode: 'MEX',
      );

      final overlays = OcrOverlayBuilder.build(matches: matches);

      expect(overlays, hasLength(1));
      expect(overlays.first.code, 'MEX9');
      expect(overlays.first.state, SlotOverlayState.confirmed);
      expect(overlays.first.readX, isNotNull);
      expect(overlays.first.w, greaterThan(overlays.first.readW!));
    });

    test('remapToPreviewSpace aligns analysis overlays to preview aspect', () {
      final overlays = OcrOverlayBuilder.build(
        matches: [
          const PortraitTextMatch(
            teamCode: 'MEX',
            slotNumber: 4,
            stickerCode: 'MEX4',
            overlayX: 0.35,
            overlayY: 0.30,
            overlayW: 0.25,
            overlayH: 0.30,
            readX: 0.44,
            readY: 0.34,
            readW: 0.06,
            readH: 0.04,
          ),
        ],
      );

      final remapped = OcrOverlayBuilder.remapToPreviewSpace(
        overlays: overlays,
        analysisImageSize: const Size(480, 640),
        previewImageSize: const Size(720, 1280),
      );

      expect(remapped, hasLength(1));
      expect(remapped.first.x, isNot(closeTo(overlays.first.x, 0.0001)));
    });
  });
}
