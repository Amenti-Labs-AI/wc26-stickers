# Pixel 4a — stock Android device testing

Install **WC26 Album Tracker** on a **Pixel 4a** running stock **Android**, build an APK on your Mac, and test live camera scan.

## Setup

1. **Settings → About phone → Build number** — tap 7× to enable Developer options
2. **Settings → System → Developer options → USB debugging** — ON
3. Connect USB, unlock phone, accept the RSA fingerprint prompt
4. Verify: `make android-devices` shows `device` (not `unauthorized`)

## Deploy

```bash
make android-device      # scan-check + flutter run on USB device
make android-install     # debug APK + adb install -r
```

Before `flutter run`, `android/scripts/run_device.sh` runs **`make scan-check`** (host OCR pipeline tests).

Use a **debug APK** when restoring collection data: `make android-push-db` requires `run-as`, which only works on debug builds.

```bash
make android-install     # install debug APK first
make android-push-db     # push data/device/panini_wc26.db → device
```

## Camera permission

If preview is black: **Settings → Apps → WC26 Album Tracker → Permissions → Camera → Allow**.

Package name: **`com.amentilabs.panini_wc26_tracker`**

Live scan uses **portrait-label OCR** only — see [ml/strategy.md](../ml/strategy.md).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `adb unauthorized` | Revoke USB debugging authorizations (Developer options), reconnect, accept RSA prompt |
| USB shows Pixel but adb empty | Enable USB debugging; try another cable/port; set USB mode to File transfer |
| `run-as` / push-db fails | Install debug APK (`make android-install`), not release |
| Black camera preview | Grant Camera permission in app settings |
| scan-check fails before deploy | Run `make scan-check` locally and fix failing tests |
