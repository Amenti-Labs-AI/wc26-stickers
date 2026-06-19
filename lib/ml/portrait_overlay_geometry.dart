import 'page_scan_service.dart';
import 'portrait_slot_from_read.dart';
import 'portrait_text_matcher.dart';
import 'slot_assignment.dart';

export 'portrait_slot_from_read.dart';

/// Template slot dimensions anchored at the OCR-read portrait center.
TemplateSlot displaySlotForOverlay({
  required TemplateSlot ocrSlot,
  TemplateSlot? templateSlot,
  double templateIouMin = 0.12,
}) {
  final tpl = templateSlot;
  if (tpl == null) return ocrSlot;

  final iou = rectIou(
    tpl.x,
    tpl.y,
    tpl.w,
    tpl.h,
    ocrSlot.x,
    ocrSlot.y,
    ocrSlot.w,
    ocrSlot.h,
  );
  if (iou >= templateIouMin) return tpl;

  final cx = ocrSlot.x + ocrSlot.w / 2;
  final cy = ocrSlot.y + ocrSlot.h / 2;
  var x = cx - tpl.w / 2;
  var y = cy - tpl.h / 2;
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  if (x + tpl.w > 1) x = 1 - tpl.w;
  if (y + tpl.h > 1) y = 1 - tpl.h;

  return TemplateSlot(
    index: tpl.index,
    stickerCode: tpl.stickerCode,
    x: x,
    y: y,
    w: tpl.w,
    h: tpl.h,
  );
}

TemplateSlot ocrPortraitSlotFromMatch(PortraitTextMatch match) => TemplateSlot(
      index: match.slotNumber,
      stickerCode: match.stickerCode,
      x: match.overlayX,
      y: match.overlayY,
      w: match.overlayW,
      h: match.overlayH,
    );

/// Portrait box derived from the OCR read rect on [match] — not template coords.
TemplateSlot portraitSlotFromOcrMatch(PortraitTextMatch match) =>
    portraitSlotFromReadRect(
      readX: match.readX,
      readY: match.readY,
      readW: match.readW,
      readH: match.readH,
      slotNumber: match.slotNumber,
      stickerCode: match.stickerCode,
    );

TemplateSlot? resolveTemplateSlot(
  PageTemplate? template,
  PortraitTextMatch match,
) {
  if (template == null) return null;
  final byCode = slotByStickerCode(template, match.stickerCode);
  if (byCode != null) return byCode;
  final readCenterX = match.readX + match.readW / 2;
  final readCenterY = match.readY + match.readH / 2;
  return nearestSlotToRead(
    template: template,
    readCenterX: readCenterX,
    readCenterY: readCenterY,
  );
}
