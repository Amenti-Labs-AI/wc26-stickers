import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'camera_frame_codec.dart';

export 'camera_frame_codec.dart';

/// Convert a live [CameraImage] frame to an upright [img.Image] for ML scan.
///
/// Prefer [CameraFramePayload.capture] + [decodeCameraFramePayload] on a
/// background isolate for live preview — this sync path blocks the UI thread.
img.Image? cameraFrameToOrientedImage(
  CameraImage frame,
  CameraDescription camera,
) {
  final payload = CameraFramePayload.capture(
    frame,
    camera,
    maxAnalysisEdge: 1 << 20,
  );
  if (payload == null) return null;
  return decodeCameraFramePayload(payload);
}
