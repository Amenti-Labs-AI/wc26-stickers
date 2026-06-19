import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/core/camera_frame_codec.dart';
import 'package:panini_wc26_tracker/ml/ocr_live_frame.dart';

void main() {
  group('orientedAnalysisDimensions', () {
    test('swaps width and height for 90° sensor orientation', () {
      const payload = CameraFramePayload(
        width: 640,
        height: 480,
        sensorOrientation: 90,
        formatName: 'nv21',
        planes: [],
        bytesPerRows: [640],
        maxAnalysisEdge: 640,
      );

      final dims = orientedAnalysisDimensions(payload);
      expect(dims.$1, 480);
      expect(dims.$2, 640);
    });

    test('keeps dimensions for 0° sensor orientation', () {
      const payload = CameraFramePayload(
        width: 640,
        height: 480,
        sensorOrientation: 0,
        formatName: 'nv21',
        planes: [],
        bytesPerRows: [640],
        maxAnalysisEdge: 640,
      );

      final dims = orientedAnalysisDimensions(payload);
      expect(dims.$1, 640);
      expect(dims.$2, 480);
    });
  });

  group('rotationFromSensor', () {
    test('maps common orientations', () {
      expect(rotationFromSensor(90).name, contains('90'));
      expect(rotationFromSensor(0).name, contains('0'));
    });
  });
}
