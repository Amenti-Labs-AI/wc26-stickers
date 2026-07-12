import 'package:flutter/material.dart';

import '../../ml/portrait_overlay_geometry.dart';
import '../../ml/portrait_text_matcher.dart';
import 'camera_preview_mapper.dart';
import 'slot_overlay_painter.dart';

/// Builds live-camera overlays from OCR portrait label matches.
class OcrOverlayBuilder {
  OcrOverlayBuilder._();

  static List<MissingSlotOverlay> build({
    required List<PortraitTextMatch> matches,
  }) {
    if (matches.isEmpty) return const [];

    final overlays = <MissingSlotOverlay>[];
    for (final match in matches) {
      if (!isPlausibleOcrReadRect(
        readW: match.readW,
        readH: match.readH,
        slotNumber: match.slotNumber,
        teamCode: match.teamCode,
      )) {
        continue;
      }
      final slot = portraitSlotFromOcrMatch(match);
      if (slot.w <= 0 || slot.h <= 0) continue;
      overlays.add(
        MissingSlotOverlay(
          code: match.stickerCode,
          displayName: match.stickerCode,
          slotNumber: match.slotNumber,
          scannedTeamCode: match.teamCode,
          x: slot.x,
          y: slot.y,
          w: slot.w,
          h: slot.h,
          readX: match.readX,
          readY: match.readY,
          readW: match.readW,
          readH: match.readH,
          state: SlotOverlayState.confirmed,
        ),
      );
    }

    return uniqueOverlays(overlays);
  }

  /// One overlay per sticker code, and at most one box per physical spot.
  static List<MissingSlotOverlay> uniqueOverlays(
    List<MissingSlotOverlay> overlays, {
    double iouThreshold = 0.35,
  }) {
    final byCode = uniqueByCode(overlays);
    if (byCode.length <= 1) return byCode;

    final ranked = List<MissingSlotOverlay>.from(byCode)
      ..sort((a, b) => _area(b).compareTo(_area(a)));
    final kept = <MissingSlotOverlay>[];
    for (final candidate in ranked) {
      final overlaps = kept.any(
        (other) => _iou(candidate, other) >= iouThreshold,
      );
      if (overlaps) continue;
      kept.add(candidate);
    }

    kept.sort(_compareOverlayPosition);
    return kept;
  }

  /// One overlay per sticker code (no spatial culling).
  static List<MissingSlotOverlay> uniqueByCode(
    List<MissingSlotOverlay> overlays,
  ) {
    if (overlays.length <= 1) {
      return List<MissingSlotOverlay>.from(overlays)
        ..sort(_compareOverlayPosition);
    }

    final byCode = <String, MissingSlotOverlay>{};
    for (final overlay in overlays) {
      final code = overlay.code.toUpperCase();
      final existing = byCode[code];
      if (existing == null) {
        byCode[code] = overlay;
        continue;
      }
      final richer = _area(overlay) > _area(existing) ? overlay : existing;
      final owned = overlay.state == SlotOverlayState.alreadyOwned ||
          existing.state == SlotOverlayState.alreadyOwned;
      byCode[code] = owned
          ? richer.copyWith(state: SlotOverlayState.alreadyOwned)
          : richer;
    }

    final kept = byCode.values.toList()..sort(_compareOverlayPosition);
    return kept;
  }

  static double _area(MissingSlotOverlay o) => o.w * o.h;

  static int _compareOverlayPosition(MissingSlotOverlay a, MissingSlotOverlay b) {
    final y = a.y.compareTo(b.y);
    if (y != 0) return y;
    return a.x.compareTo(b.x);
  }

  static double _iou(MissingSlotOverlay a, MissingSlotOverlay b) {
    final ax2 = a.x + a.w;
    final ay2 = a.y + a.h;
    final bx2 = b.x + b.w;
    final by2 = b.y + b.h;
    final ix1 = a.x > b.x ? a.x : b.x;
    final iy1 = a.y > b.y ? a.y : b.y;
    final ix2 = ax2 < bx2 ? ax2 : bx2;
    final iy2 = ay2 < by2 ? ay2 : by2;
    final iw = ix2 - ix1;
    final ih = iy2 - iy1;
    if (iw <= 0 || ih <= 0) return 0;
    final inter = iw * ih;
    final union = _area(a) + _area(b) - inter;
    if (union <= 0) return 0;
    return inter / union;
  }

  /// OCR runs on the oriented analysis frame; the preview may use a different
  /// aspect ratio — remap overlays so they align with [CameraCoverPreview].
  static List<MissingSlotOverlay> remapToPreviewSpace({
    required List<MissingSlotOverlay> overlays,
    required Size analysisImageSize,
    required Size previewImageSize,
  }) {
    if (overlays.isEmpty) return overlays;
    if (analysisImageSize == previewImageSize) return overlays;

    final view = referenceCoverViewSize(previewImageSize);
    return [
      for (final slot in overlays)
        _remapSlot(
          slot,
          analysisImageSize: analysisImageSize,
          previewImageSize: previewImageSize,
          viewSize: view,
        ),
    ];
  }

  static MissingSlotOverlay _remapSlot(
    MissingSlotOverlay slot, {
    required Size analysisImageSize,
    required Size previewImageSize,
    required Size viewSize,
  }) {
    final body = remapNormalizedRectBetweenImages(
      x: slot.x,
      y: slot.y,
      w: slot.w,
      h: slot.h,
      fromImage: analysisImageSize,
      toImage: previewImageSize,
      viewSize: viewSize,
    );

    double? readX;
    double? readY;
    double? readW;
    double? readH;
    if (slot.readX != null &&
        slot.readY != null &&
        slot.readW != null &&
        slot.readH != null) {
      final read = remapNormalizedRectBetweenImages(
        x: slot.readX!,
        y: slot.readY!,
        w: slot.readW!,
        h: slot.readH!,
        fromImage: analysisImageSize,
        toImage: previewImageSize,
        viewSize: viewSize,
      );
      readX = read.x;
      readY = read.y;
      readW = read.w;
      readH = read.h;
    }

    return MissingSlotOverlay(
      code: slot.code,
      displayName: slot.displayName,
      slotNumber: slot.slotNumber,
      scannedTeamCode: slot.scannedTeamCode,
      x: body.x,
      y: body.y,
      w: body.w,
      h: body.h,
      readX: readX,
      readY: readY,
      readW: readW,
      readH: readH,
      state: slot.state,
    );
  }
}
