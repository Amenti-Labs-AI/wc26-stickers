import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decode JPEG bytes and apply EXIF orientation so pixel layout matches preview.
img.Image? decodeOrientedJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return img.bakeOrientation(decoded);
}
