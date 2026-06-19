import 'package:flutter/material.dart';

import 'slot_overlay_painter.dart';

/// Widget-based overlay atop [CameraPreview]. Must fill the stack (explicit size).
class SlotOverlayLayer extends StatelessWidget {
  const SlotOverlayLayer({
    super.key,
    required this.slots,
    this.imageSize,
    this.fit = BoxFit.cover,
  });

  final List<MissingSlotOverlay> slots;
  final Size? imageSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = Size(constraints.maxWidth, constraints.maxHeight);
        return IgnorePointer(
          child: SizedBox(
            width: canvas.width,
            height: canvas.height,
            child: CustomPaint(
              painter: MissingSlotOverlayPainter(
                slots: slots,
                imageSize: imageSize,
                fit: fit,
              ),
              size: canvas,
            ),
          ),
        );
      },
    );
  }
}
