import 'dart:math' as math;

import 'page_scan_service.dart';

/// National-team spreads use slot 13 for the landscape team-photo banner.
bool isTeamPhotoSlot(int slotNumber) => slotNumber == 13;

/// FWC intro foil banners (e.g. FWC3 mascots, FWC4 slogan) are landscape wells.
bool isFwcLandscapeFoilSlot(String teamCode, int slotNumber) =>
    teamCode.toUpperCase() == 'FWC' && slotNumber >= 3 && slotNumber <= 8;

/// Whether OCR label geometry should expand into a landscape sticker well.
bool isLandscapeOcrSlot({
  required int slotNumber,
  required String teamCode,
  required double readW,
  required double readH,
}) {
  if (isTeamPhotoSlot(slotNumber)) return true;
  if (isFwcLandscapeFoilSlot(teamCode, slotNumber)) return true;
  // Side-by-side team+number reads span a wide label cluster.
  if (readW >= 0.10 && readH > 0.004 && readW / readH >= 1.8) return true;
  return false;
}

/// How much of slot width/height the stacked OCR label (team + number) occupies.
const ocrLabelWidthShare = 0.46;
const ocrLabelHeightShare = 0.22;
const ocrLabelTopInset = 0.18;

/// Team-photo banner (slot 13): label sits top-left; bar extends right.
const ocrLandscapeLabelWidthShare = 0.22;
const ocrLandscapeLabelHeightShare = 0.42;
const ocrLandscapeLeftInset = 0.06;
const ocrLandscapeTopInset = 0.10;
const maxLandscapeSlotWidth = 0.28;
const maxLandscapeSlotHeight = 0.12;
const minLandscapeAspect = 2.0;

/// Reject OCR clusters too large to be a portrait label (footer / player names).
const maxOcrReadWidth = 0.14;
const maxOcrReadHeight = 0.10;
const maxPortraitSlotWidth = 0.22;
const maxPortraitSlotHeight = 0.28;

const maxLandscapeOcrReadWidth = 0.22;

bool isPlausibleOcrReadRect({
  required double readW,
  required double readH,
  int slotNumber = 0,
  String teamCode = '',
}) {
  if (readW <= 0.004 || readH <= 0.004) return false;
  final landscape = isLandscapeOcrSlot(
    slotNumber: slotNumber,
    teamCode: teamCode,
    readW: readW,
    readH: readH,
  );
  if (landscape) {
    return readW <= maxLandscapeOcrReadWidth && readH <= maxOcrReadHeight;
  }
  return readW <= maxOcrReadWidth && readH <= maxOcrReadHeight;
}

/// Expands the OCR label bounding box outward to the sticker well edges.
///
/// Portrait player slots (all numbers except 13) grow downward from a centered
/// label. Slot 13 team-photo banners grow rightward from a top-left label.
TemplateSlot portraitSlotFromReadRect({
  required double readX,
  required double readY,
  required double readW,
  required double readH,
  required int slotNumber,
  required String stickerCode,
}) {
  if (!isPlausibleOcrReadRect(readW: readW, readH: readH)) {
    return _emptySlot(slotNumber: slotNumber, stickerCode: stickerCode);
  }

  return isLandscapeOcrSlot(
        slotNumber: slotNumber,
        teamCode: stickerCode.replaceAll(RegExp(r'\d+$'), ''),
        readW: readW,
        readH: readH,
      )
      ? _landscapeTeamPhotoSlotFromReadRect(
          readX: readX,
          readY: readY,
          readW: readW,
          readH: readH,
          slotNumber: slotNumber,
          stickerCode: stickerCode,
        )
      : _portraitPlayerSlotFromReadRect(
          readX: readX,
          readY: readY,
          readW: readW,
          readH: readH,
          slotNumber: slotNumber,
          stickerCode: stickerCode,
        );
}

TemplateSlot _emptySlot({
  required int slotNumber,
  required String stickerCode,
}) =>
    TemplateSlot(
      index: slotNumber,
      stickerCode: stickerCode,
      x: 0,
      y: 0,
      w: 0,
      h: 0,
    );

TemplateSlot _portraitPlayerSlotFromReadRect({
  required double readX,
  required double readY,
  required double readW,
  required double readH,
  required int slotNumber,
  required String stickerCode,
}) {
  final safeW = math.max(readW, 0.008);
  final safeH = math.max(readH, 0.006);

  final wFromLabel = safeW / ocrLabelWidthShare;
  final hFromLabel = safeH / ocrLabelHeightShare;
  final w = wFromLabel.clamp(0.08, maxPortraitSlotWidth);
  final h = hFromLabel.clamp(0.10, maxPortraitSlotHeight);
  final cx = readX + safeW / 2;

  var top = readY - h * ocrLabelTopInset;
  var left = cx - w / 2;

  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (left + w > 1) left = 1 - w;
  if (top + h > 1) top = 1 - h;

  return TemplateSlot(
    index: slotNumber,
    stickerCode: stickerCode,
    x: left,
    y: top,
    w: w,
    h: h,
  );
}

TemplateSlot _landscapeTeamPhotoSlotFromReadRect({
  required double readX,
  required double readY,
  required double readW,
  required double readH,
  required int slotNumber,
  required String stickerCode,
}) {
  final safeW = math.max(readW, 0.008);
  final safeH = math.max(readH, 0.006);

  var w = (safeW / ocrLandscapeLabelWidthShare).clamp(0.14, maxLandscapeSlotWidth);
  var h = (safeH / ocrLandscapeLabelHeightShare).clamp(0.06, maxLandscapeSlotHeight);

  if (w / h < minLandscapeAspect) {
    w = (h * minLandscapeAspect).clamp(0.14, maxLandscapeSlotWidth);
  }

  var left = readX - w * ocrLandscapeLeftInset;
  var top = readY - h * ocrLandscapeTopInset;

  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (left + w > 1) left = 1 - w;
  if (top + h > 1) top = 1 - h;

  return TemplateSlot(
    index: slotNumber,
    stickerCode: stickerCode,
    x: left,
    y: top,
    w: w,
    h: h,
  );
}
