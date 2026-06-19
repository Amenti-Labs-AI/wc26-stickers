# ML strategy — WC26 Album Tracker

Last updated: 2026-06-19

## Production path (live Scan tab)

**Portrait-label OCR** is the only scan path shipped today.

```
Camera frame
  → ML Kit TextRecognizer (NV21/BGRA fast path when possible)
  → PortraitTextMatcher (stacked team + number, horizontal FWC labels)
  → Catalog validation (page templates / sticker codes)
  → Team lock + overlay + DB persist
```

| Component | Role |
|-----------|------|
| `ScanPageSession` | Orchestrates live/still scans, team lock, post-filter |
| `PortraitOcrScanner` | OCR + match pipeline |
| `PageScanService` | Template catalog + ML Kit recognizer factory |
| `LiveOverlayTracker` | Stabilize noisy frames |
| `missing_scan_filter` | Lock to active team page |

**Integration tests:** `make scan-check` (host synthetics) + `make scan-check-device` (21 tests on USB Android/iOS).

Fixtures: `assets/test_fixtures/`. Helpers: `test/helpers/portrait_ocr_fixtures.dart`.

## Extensibility

New scan pipelines add a `ScanEngine` enum value and a dedicated scanner class wired through `ScanPageSession`.
