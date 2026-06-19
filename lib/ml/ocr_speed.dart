/// OCR quality vs speed trade-off for live camera vs still-image scan.
enum OcrSpeed {
  /// Full half-page — single pass at moderate upscale.
  standard,

  /// Smaller images, single pass — live camera stream.
  live,

  /// Zoomed crop — aggressive upscale + dual OCR pass.
  crop,
}
