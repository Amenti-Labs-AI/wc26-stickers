/// One OCR text line with normalized bounding box (0–1 relative to page image).
class OcrTextLine {
  const OcrTextLine({
    required this.text,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// Coerces platform/OCR numeric values (sometimes [int]) to [double].
  factory OcrTextLine.fromNums({
    required String text,
    required num x,
    required num y,
    required num w,
    required num h,
  }) =>
      OcrTextLine(
        text: text,
        x: x.toDouble(),
        y: y.toDouble(),
        w: w.toDouble(),
        h: h.toDouble(),
      );

  final String text;
  final double x;
  final double y;
  final double w;
  final double h;

  double get centerX => x + w / 2;
  double get centerY => y + h / 2;
  double get top => y;
  double get bottom => y + h;
  double get right => x + w;

  String get normalizedText =>
      text.toUpperCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();

  OcrTextLine mergeWith(OcrTextLine other) {
    final left = x < other.x ? x : other.x;
    final top = y < other.y ? y : other.y;
    final right = this.right > other.right ? this.right : other.right;
    final bottom = this.bottom > other.bottom ? this.bottom : other.bottom;
    return OcrTextLine(
      text: '$text\n${other.text}',
      x: left,
      y: top,
      w: right - left,
      h: bottom - top,
    );
  }
}
