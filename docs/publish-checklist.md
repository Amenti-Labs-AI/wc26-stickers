# Store publish checklist

WC26 Stickers — App Store / Play Console prep.

## Identifiers

| Platform | Value |
|----------|--------|
| Android `applicationId` | `com.amentilabs.wc26stickers` |
| iOS bundle ID | `com.amentilabs.wc26Stickers` |
| Display name | WC26 Stickers |
| Version | from `pubspec.yaml` (`1.0.0+1` → name+build) |

Fresh package IDs: sideloaded installs of the old `panini_*` IDs will not upgrade in place.

## Android Play

1. Create an upload keystore (do **not** commit it):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Write `android/key.properties` (gitignored):

   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

3. Build AAB: `make android-aab` or `make release`
4. Play Console → Data safety (approx.):
   - No account, no sale of data
   - Camera (optional): album page scan, processed on-device
   - On-device ML Kit text recognition; no cloud OCR
   - Local SQLite collection data only
5. Screenshots: phone + 7" tablet if targeting; feature graphic 1024×500
6. Privacy policy URL: `https://amentilabs.dev/` (or a dedicated policy page)
7. Content rating questionnaire; declare unaffiliated / fan utility

## iOS App Store

1. Set `DEVELOPMENT_TEAM` in Xcode for `com.amentilabs.wc26Stickers`
2. Archive / `flutter build ipa --release` (or `make release` on macOS)
3. App Privacy: camera for scanning; data not linked to identity; no tracking
4. Export compliance: `ITSAppUsesNonExemptEncryption` = false (OS TLS only)
5. Privacy Manifest: `ios/Runner/PrivacyInfo.xcprivacy`
6. Review notes: unaffiliated fan sticker tracker; camera optional for Need-list OCR

## Branding / legal

- In-app Settings states the app is not affiliated with Panini or FIFA
- Cover-side art and WC marks: confirm trademark/license before store screenshots that feature them
- Proprietary LICENSE — not open source

## Pre-upload verification

```bash
make ci
make android-aab
# Confirm release bundle has no OCR fixtures:
unzip -l build/app/outputs/bundle/release/app-release.aab | grep test_fixtures && echo FAIL || echo OK
```

Bump `version:` in `pubspec.yaml` for each store upload.
