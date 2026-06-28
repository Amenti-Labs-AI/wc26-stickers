# WC26 Album Tracker

Mobile app for **Panini FIFA World Cup 2026** collectors: track owned and missing stickers simply by scanning album pages with the phone camera to automatically mark  stickers as missing from collection.

## AI & computer vision

All scan inference runs **on-device**. Nothing is sent to the cloud.

Empty placeholders print the **team code and slot number** (e.g. `MEX` / `4`). The app reads those labels from the live camera feed with **Google ML Kit text recognition**, pairs reads against the bundled catalog, locks to the active team page, and persists confirmed missing codes.

| Stage | How |
|-------|-----|
| **Input** | Camera frames (NV21/BGRA fast path when available) |
| **OCR** | ML Kit `TextRecognizer` on portrait labels and horizontal FWC codes |
| **Matching** | `PortraitTextMatcher` + page templates for valid sticker codes |
| **Stabilization** | Frame tracker to reduce flicker on noisy reads |
| **Output** | Red overlays on missing slots; auto-save to collection |

Portrait-label OCR was chosen over generic empty-box detection because WC26 layouts mix portrait wells, landscape team photos, and foil types — printed text on empties is more reliable than training one detector for every page geometry.

## Tech stack

| Layer | Technology |
|-------|------------|
| **App** | Flutter 3.5+ (Dart) |
| **Mobile targets** | iOS (Xcode 15+), Android (API 21+) |
| **Computer vision** | Google ML Kit Text Recognition |
| **Camera** | `camera` plugin |
| **Local DB** | SQLite via `sqflite` |
| **State** | Riverpod |
| **CI** | GitHub Actions — analyze + unit tests |

## Screenshots

**Live scan (Brazil)**

![Live scan on Brazil team page — need slots highlighted](docs/screenshots/bra-scan-1.png)

**Live scan (Switzerland)**

![Live scan on Switzerland team page — need slots highlighted](docs/screenshots/sui-scan-2.png)

**Home**

![Home — album progress, need and swaps summary](docs/screenshots/home.png)

**Collection — team page**

![Collection team grid with owned and need stickers](docs/screenshots/collection-team.png)

**Collection — edit sticker**

![Sticker edit sheet for owned, need, and swaps](docs/screenshots/collection-edit.png)

## Development

Build, test, device deploy, and scan pipeline details: **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**

## License

[MIT](LICENSE) — Copyright © 2026 [Amenti Labs, LLC](https://amentilabs.dev/)

This project licenses **source code only**. Panini, FIFA, and related album artwork and trademarks belong to their respective owners and are not covered by this license.
