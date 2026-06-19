# Pixel 4 / GrapheneOS — device testing

Install **WC26 Album Tracker** on a **Pixel 4** running **GrapheneOS**, build an APK on your Mac, and test live camera scan.

## Deploy

```bash
make android-device      # scan-check + flutter run on USB device
make android-install     # debug APK + adb install -r
```

Before `flutter run`, `android/scripts/run_device.sh` runs **`make scan-check`** (host OCR pipeline tests).

## Camera permission

If preview is black: **Settings → Apps → WC26 Album Tracker → Permissions → Camera → Allow**.

Package name: **`com.amentilabs.panini_wc26_tracker`**

Live scan uses **portrait-label OCR** only — see [ml/strategy.md](../ml/strategy.md).
