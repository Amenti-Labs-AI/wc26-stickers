import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Pick a JPEG/PNG from the photo library or filesystem (simulator-friendly).
Future<Uint8List?> pickScanImageBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  if (file.bytes != null) return file.bytes;
  final path = file.path;
  if (path != null) return File(path).readAsBytes();
  return null;
}

/// File path when the platform provides one (ML Kit file input).
Future<String?> pickScanImagePath() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.first.path;
}
