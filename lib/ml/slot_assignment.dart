import 'dart:math' as math;

import 'page_scan_service.dart';

class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;
}

/// Reading order: top→bottom, left→right (Panini page layout).
int compareReadingOrder(double ay, double ax, double by, double bx) {
  if ((ay - by).abs() > 0.04) return ay.compareTo(by);
  return ax.compareTo(bx);
}

NormalizedRect normalizedFromSlot(TemplateSlot slot) => NormalizedRect(
      x: slot.x,
      y: slot.y,
      w: slot.w,
      h: slot.h,
    );

/// Resolve a template slot by catalog [stickerCode], if present.
TemplateSlot? slotByStickerCode(PageTemplate template, String stickerCode) {
  final upper = stickerCode.toUpperCase();
  for (final slot in template.slots) {
    if (slot.stickerCode.toUpperCase() == upper) return slot;
  }
  return null;
}

/// Nearest template slot center to an OCR read position (normalized 0–1).
TemplateSlot? nearestSlotToRead({
  required PageTemplate template,
  required double readCenterX,
  required double readCenterY,
}) {
  if (template.slots.isEmpty) return null;
  TemplateSlot? best;
  var bestDist = double.infinity;
  for (final slot in template.slots) {
    final bcx = slot.x + slot.w / 2;
    final bcy = slot.y + slot.h / 2;
    final dist = (readCenterX - bcx) * (readCenterX - bcx) +
        (readCenterY - bcy) * (readCenterY - bcy);
    if (dist < bestDist) {
      bestDist = dist;
      best = slot;
    }
  }
  return best;
}

double rectIou(
  double ax,
  double ay,
  double aw,
  double ah,
  double bx,
  double by,
  double bw,
  double bh,
) {
  final x1 = math.max(ax, bx);
  final y1 = math.max(ay, by);
  final x2 = math.min(ax + aw, bx + bw);
  final y2 = math.min(ay + ah, by + bh);
  final inter = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
  if (inter <= 0) return 0;
  final union = aw * ah + bw * bh - inter;
  return union <= 0 ? 0 : inter / union;
}
