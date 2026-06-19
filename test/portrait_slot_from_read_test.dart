import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/ml/portrait_slot_from_read.dart';

void main() {
  group('portraitSlotFromReadRect', () {
    test('scales from OCR read bbox not fixed minimums', () {
      // page_8 MEX4-ish OCR cluster from device integration run.
      const readX = 0.462;
      const readY = 0.371;
      const readW = 0.06;
      const readH = 0.051;

      final slot = portraitSlotFromReadRect(
        readX: readX,
        readY: readY,
        readW: readW,
        readH: readH,
        slotNumber: 4,
        stickerCode: 'MEX4',
      );

      expect(slot.w, closeTo(readW / ocrLabelWidthShare, 0.01));
      expect(slot.h, closeTo(readH / ocrLabelHeightShare, 0.01));
      expect(slot.w, lessThan(0.24));
      expect(slot.h, lessThan(0.30));
      expect(slot.y, lessThan(readY));
      expect(slot.x + slot.w / 2, closeTo(readX + readW / 2, 0.02));
      expect(slot.y + slot.h, greaterThan(readY + readH));
    });

    test('rejects oversized OCR read clusters', () {
      final slot = portraitSlotFromReadRect(
        readX: 0.1,
        readY: 0.8,
        readW: 0.40,
        readH: 0.08,
        slotNumber: 1,
        stickerCode: 'MEX1',
      );
      expect(slot.w, 0);
      expect(slot.h, 0);
    });

    test('read rect sits inside portrait slot', () {
      final slot = portraitSlotFromReadRect(
        readX: 0.60,
        readY: 0.66,
        readW: 0.06,
        readH: 0.04,
        slotNumber: 9,
        stickerCode: 'MEX9',
      );

      expect(slot.x, lessThanOrEqualTo(0.60));
      expect(slot.y, lessThanOrEqualTo(0.66));
      expect(slot.x + slot.w, greaterThanOrEqualTo(0.66));
      expect(slot.y + slot.h, greaterThanOrEqualTo(0.70));
    });

    test('slot 13 team photo uses landscape aspect', () {
      const readX = 0.72;
      const readY = 0.04;
      const readW = 0.05;
      const readH = 0.045;

      final slot = portraitSlotFromReadRect(
        readX: readX,
        readY: readY,
        readW: readW,
        readH: readH,
        slotNumber: 13,
        stickerCode: 'MEX13',
      );

      expect(slot.w, greaterThan(slot.h));
      expect(slot.w / slot.h, greaterThanOrEqualTo(minLandscapeAspect));
      expect(slot.x, lessThanOrEqualTo(readX));
      expect(slot.y, lessThanOrEqualTo(readY));
      expect(slot.x + slot.w, greaterThan(readX + readW));
    });

    test('isTeamPhotoSlot is only slot 13', () {
      expect(isTeamPhotoSlot(13), isTrue);
      expect(isTeamPhotoSlot(12), isFalse);
      expect(isTeamPhotoSlot(14), isFalse);
    });

    test('FWC4 uses landscape aspect', () {
      const readX = 0.10;
      const readY = 0.30;
      const readW = 0.05;
      const readH = 0.04;

      final slot = portraitSlotFromReadRect(
        readX: readX,
        readY: readY,
        readW: readW,
        readH: readH,
        slotNumber: 4,
        stickerCode: 'FWC4',
      );

      expect(slot.w, greaterThan(slot.h));
      expect(slot.w / slot.h, greaterThanOrEqualTo(minLandscapeAspect));
    });

    test('FWC1 stays portrait', () {
      final slot = portraitSlotFromReadRect(
        readX: 0.10,
        readY: 0.15,
        readW: 0.05,
        readH: 0.04,
        slotNumber: 1,
        stickerCode: 'FWC1',
      );

      expect(slot.h, greaterThan(slot.w));
    });

    test('wide horizontal OCR read uses landscape without slot hint', () {
      final slot = portraitSlotFromReadRect(
        readX: 0.10,
        readY: 0.30,
        readW: 0.16,
        readH: 0.05,
        slotNumber: 2,
        stickerCode: 'MEX2',
      );

      expect(slot.w / slot.h, greaterThanOrEqualTo(minLandscapeAspect));
    });
  });
}
