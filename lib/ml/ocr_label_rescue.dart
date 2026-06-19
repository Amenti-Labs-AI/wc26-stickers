import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'ocr_speed.dart';
import 'ocr_text_line.dart';
import 'portrait_text_matcher.dart';
import 'template_ocr.dart';

const maxLabelRescuesPerScan = 2;

/// Normalized crop band around a team label for supplemental digit OCR.
({double x, double y, double w, double h}) labelBandForTeamLine(OcrTextLine teamLine) {
  const bandW = 0.20;
  const bandH = 0.07;
  var x = teamLine.centerX - bandW / 2;
  var y = teamLine.centerY - 0.01;
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  if (x + bandW > 1) x = 1 - bandW;
  if (y + bandH > 1) y = 1 - bandH;
  return (x: x, y: y, w: bandW, h: bandH);
}

/// Maps OCR lines from a normalized crop back to full-page coordinates.
List<OcrTextLine> remapCropLinesToPage(
  List<OcrTextLine> cropLines, {
  required double cropX,
  required double cropY,
  required double cropW,
  required double cropH,
}) {
  return [
    for (final line in cropLines)
      OcrTextLine.fromNums(
        text: line.text,
        x: cropX + line.x * cropW,
        y: cropY + line.y * cropH,
        w: line.w * cropW,
        h: line.h * cropH,
      ),
  ];
}

List<OcrTextLine> mergeOcrLineLists(
  List<OcrTextLine> primary,
  List<OcrTextLine> extra,
) {
  final merged = [...primary];
  for (final line in extra) {
    final duplicate = merged.any(
      (existing) =>
          existing.normalizedText == line.normalizedText &&
          (existing.centerX - line.centerX).abs() < 0.04 &&
          (existing.centerY - line.centerY).abs() < 0.04,
    );
    if (!duplicate) merged.add(line);
  }
  return merged;
}

img.Image cropNormImage(
  img.Image page, {
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  return img.copyCrop(
    page,
    x: (x * page.width).round().clamp(0, page.width - 1),
    y: (y * page.height).round().clamp(0, page.height - 1),
    width: (w * page.width).round().clamp(1, page.width),
    height: (h * page.height).round().clamp(1, page.height),
  );
}

/// Re-OCRs tight bands around team lines that did not pair with a slot number.
Future<List<OcrTextLine>> rescueUnpairedTeamLabels({
  required TextRecognizer recognizer,
  required img.Image page,
  required PortraitTextMatcher matcher,
  required List<OcrTextLine> lines,
  required List<PortraitTextMatch> matches,
  required Set<String> knownTeamCodes,
  String? filterTeamCode,
}) async {
  final unpaired = matcher.findUnpairedTeamLines(
    lines: lines,
    matches: matches,
    knownTeamCodes: knownTeamCodes,
    filterTeamCode: filterTeamCode,
  );
  if (unpaired.isEmpty) return lines;

  // Prefer lower-page labels where faint digits are most often missed.
  unpaired.sort((a, b) => b.centerY.compareTo(a.centerY));

  var merged = lines;
  var rescueCount = 0;
  for (final teamLine in unpaired) {
    if (rescueCount >= maxLabelRescuesPerScan) break;

    final band = labelBandForTeamLine(teamLine);
    final crop = cropNormImage(
      page,
      x: band.x,
      y: band.y,
      w: band.w,
      h: band.h,
    );
    final cropLines = await ocrPageTextLines(
      recognizer,
      crop,
      speed: OcrSpeed.crop,
    );
    if (cropLines.isEmpty) continue;

    merged = mergeOcrLineLists(
      merged,
      remapCropLinesToPage(
        cropLines,
        cropX: band.x,
        cropY: band.y,
        cropW: band.w,
        cropH: band.h,
      ),
    );
    rescueCount++;
  }

  return merged;
}
