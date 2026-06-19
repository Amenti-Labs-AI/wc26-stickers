import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ml/portrait_slot_from_read.dart';
import 'camera_preview_mapper.dart';

enum SlotOverlayState { scanning, confirmed }

/// A missing (empty) sticker slot to draw on the live camera overlay.
class MissingSlotOverlay {
  const MissingSlotOverlay({
    required this.code,
    required this.displayName,
    required this.slotNumber,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.state = SlotOverlayState.confirmed,
    this.readX,
    this.readY,
    this.readW,
    this.readH,
    this.scannedTeamCode,
  });

  final String code;
  final String displayName;
  final int slotNumber;
  final double x;
  final double y;
  final double w;
  final double h;
  final SlotOverlayState state;
  final double? readX;
  final double? readY;
  final double? readW;
  final double? readH;
  /// When set, label shows team code on top and [slotNumber] below (portrait readout).
  final String? scannedTeamCode;

  Rect rectForCanvas(Size canvasSize, {Size? imageSize, BoxFit fit = BoxFit.cover}) {
    if (imageSize == null) {
      return Rect.fromLTWH(
        x * canvasSize.width,
        y * canvasSize.height,
        w * canvasSize.width,
        h * canvasSize.height,
      );
    }
    return mapNormalizedRect(
      x: x,
      y: y,
      w: w,
      h: h,
      imageSize: imageSize,
      viewSize: canvasSize,
      fit: fit,
    );
  }

  Rect? readRectForCanvas(Size canvasSize, {Size? imageSize, BoxFit fit = BoxFit.cover}) {
    final rx = readX;
    final ry = readY;
    final rw = readW;
    final rh = readH;
    if (rx == null || ry == null || rw == null || rh == null) return null;
    if (imageSize == null) {
      return Rect.fromLTWH(
        rx * canvasSize.width,
        ry * canvasSize.height,
        rw * canvasSize.width,
        rh * canvasSize.height,
      );
    }
    return mapNormalizedRect(
      x: rx,
      y: ry,
      w: rw,
      h: rh,
      imageSize: imageSize,
      viewSize: canvasSize,
      fit: fit,
    );
  }

  /// Label band for the team+number readout inside the slot rect.
  Rect labelBandRect(Rect slotRect) {
    final landscape = isLandscapeOcrSlot(
      slotNumber: slotNumber,
      teamCode: scannedTeamCode ?? '',
      readW: readW ?? 0,
      readH: readH ?? 0,
    );
    if (landscape) {
      return Rect.fromLTWH(
        slotRect.left,
        slotRect.top,
        slotRect.width * 0.42,
        slotRect.height * 0.55,
      );
    }
    final bandTop = slotRect.top + slotRect.height * 0.55;
    final bandHeight = slotRect.height * 0.45;
    return Rect.fromLTWH(
      slotRect.left,
      bandTop,
      slotRect.width,
      bandHeight,
    );
  }
}

/// Paints red highlight boxes and labels for empty sticker slots on the page.
class MissingSlotOverlayPainter extends CustomPainter {
  MissingSlotOverlayPainter({
    required this.slots,
    this.imageSize,
    this.fit = BoxFit.cover,
  });

  final List<MissingSlotOverlay> slots;
  final Size? imageSize;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    for (final slot in slots) {
      final rect = slot.rectForCanvas(size, imageSize: imageSize, fit: fit);
      if (rect.width < 4 || rect.height < 4) continue;

      if (slot.state == SlotOverlayState.scanning) {
        _paintScanning(canvas, rect, slot, size);
      } else {
        _paintConfirmed(canvas, rect, slot);
      }
    }
  }

  void _paintScanning(Canvas canvas, Rect rect, MissingSlotOverlay slot, Size size) {
    final radius = Radius.circular(
      (math.min(rect.width, rect.height) * 0.08).clamp(3.0, 10.0),
    );

    final fill = Paint()
      ..color = const Color(0x40FFB300)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);

    _paintDashedBorder(canvas, rect, radius, const Color(0xFFFFB300), 2);

    final readRect = slot.readRectForCanvas(size, imageSize: imageSize, fit: fit);
    if (readRect != null && readRect.width >= 4 && readRect.height >= 4) {
      final readFill = Paint()
        ..color = const Color(0x55FFB300)
        ..style = PaintingStyle.fill;
      canvas.drawRect(readRect, readFill);
    }

    _drawPortraitLabel(canvas, slot.labelBandRect(rect), slot, scanning: true);
  }

  void _paintConfirmed(Canvas canvas, Rect rect, MissingSlotOverlay slot) {
    final radius = Radius.circular(
      (math.min(rect.width, rect.height) * 0.08).clamp(3.0, 10.0),
    );

    final fill = Paint()
      ..color = const Color(0x8CFF1744)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), border);
    _drawPortraitLabel(canvas, slot.labelBandRect(rect), slot);
  }

  void _paintDashedBorder(
    Canvas canvas,
    Rect rect,
    Radius radius,
    Color color,
    double strokeWidth,
  ) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(
      _dashPath(path, dashArray: const [6, 4]),
      paint,
    );
  }

  Path _dashPath(Path source, {required List<double> dashArray}) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      var dashIndex = 0;
      while (distance < metric.length) {
        final dash = dashArray[dashIndex % dashArray.length];
        final next = math.min(distance + dash, metric.length);
        if (draw) {
          dashed.addPath(
            metric.extractPath(distance, next),
            Offset.zero,
          );
        }
        distance = next;
        draw = !draw;
        dashIndex++;
      }
    }
    return dashed;
  }

  void _drawPortraitLabel(
    Canvas canvas,
    Rect rect,
    MissingSlotOverlay slot, {
    bool scanning = false,
  }) {
    final team = slot.scannedTeamCode ?? _teamFromCode(slot.code);
    if (team.isEmpty || team == '…') return;
    final number = slot.slotNumber > 0 ? '${slot.slotNumber}' : '?';
    final color = scanning ? const Color(0xFFFFF8E1) : Colors.white;

    final teamPainter = TextPainter(
      text: TextSpan(
        text: team,
        style: TextStyle(
          color: color,
          fontSize: scanning ? 13 : 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width - 4);

    final numberPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          color: color,
          fontSize: scanning ? 16 : 20,
          fontWeight: FontWeight.w800,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width - 4);

    final name = slot.displayName;
    final showName = !scanning &&
        name.isNotEmpty &&
        name != slot.code &&
        !name.startsWith('Reading');
    TextPainter? namePainter;
    if (showName) {
      namePainter = TextPainter(
        text: TextSpan(
          text: name.length > 18 ? '${name.substring(0, 16)}…' : name,
          style: const TextStyle(
            color: Color(0xFFFFF9C4),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: rect.width - 4);
    }

    final nameH = namePainter?.height ?? 0;
    final gap = showName ? 2.0 : 0.0;
    final totalH = teamPainter.height + numberPainter.height + nameH + gap;
    var dy = rect.top + (rect.height - totalH) / 2;

    final cx = rect.left + rect.width / 2;
    teamPainter.paint(canvas, Offset(cx - teamPainter.width / 2, dy));
    dy += teamPainter.height;
    numberPainter.paint(canvas, Offset(cx - numberPainter.width / 2, dy));
    if (namePainter != null) {
      dy += numberPainter.height + gap;
      namePainter.paint(canvas, Offset(cx - namePainter.width / 2, dy));
    }
  }

  String _teamFromCode(String code) {
    final m = RegExp(r'^([A-Z]{2,3})').firstMatch(code.toUpperCase());
    return m?.group(1) ?? code;
  }

  @override
  bool shouldRepaint(covariant MissingSlotOverlayPainter oldDelegate) =>
      oldDelegate.imageSize != imageSize ||
      oldDelegate.fit != fit ||
      oldDelegate.slots.length != slots.length ||
      !_sameSlots(oldDelegate.slots, slots);

  bool _sameSlots(List<MissingSlotOverlay> a, List<MissingSlotOverlay> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.code != right.code || left.state != right.state) return false;
      if ((left.x - right.x).abs() > 0.008) return false;
      if ((left.y - right.y).abs() > 0.008) return false;
    }
    return true;
  }
}
