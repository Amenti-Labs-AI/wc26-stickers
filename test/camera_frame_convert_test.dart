import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/camera_image_convert.dart';

void main() {
  group('cameraFrameToOrientedImage', () {
    test('converts single-plane NV21 and rotates for sensorOrientation 90', () {
      if (defaultTargetPlatform != TargetPlatform.android) {
        // NV21 format id 17 is only mapped on Android hosts.
        return;
      }
      const width = 640;
      const height = 480;
      final bytes = Uint8List.fromList(
        List<int>.filled(width * height + (width * height ~/ 2), 128),
      );
      final frame = CameraImage.fromPlatformData({
        'width': width,
        'height': height,
        'format': 17, // Android NV21
        'planes': [
          {
            'bytes': bytes,
            'bytesPerRow': width,
            'bytesPerPixel': 1,
          },
        ],
      });
      const camera = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      final image = cameraFrameToOrientedImage(frame, camera);
      expect(image, isNotNull);
      expect(image!.width, height);
      expect(image.height, width);
    });
  });
}
