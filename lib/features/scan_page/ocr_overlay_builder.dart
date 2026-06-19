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

    overlays.sort((a, b) {
      final y = a.y.compareTo(b.y);
      if (y != 0) return y;
      return a.x.compareTo(b.x);
    });
    return overlays;
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
