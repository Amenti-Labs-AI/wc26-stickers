/// Central scan confidence thresholds (baseline — tuned for live empty-slot overlays).
abstract final class ScanThresholds {
  static const mlConfidence = 0.15;
  static const mlSlotIou = 0.25;
  static const templateSlotIou = 0.08;

  static const heuristicEmptySaturation = 0.237;
  static const heuristicFilledVariance = 800.0;

  static const templateDetectMin = 0.4;
  static const templateDetectAmbiguous = 0.55;
  static const templateWeakMin = 0.22;
  static const ocrMatchConfidence = 0.85;
}
