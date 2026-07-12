# Store publish checklist

WC26 Stickers — App Store / Play Console prep.

## Identifiers

| Platform | Value |
|----------|--------|
| Android `applicationId` | `com.amentilabs.wc26stickers` |
| iOS bundle ID | `com.amentilabs.wc26Stickers` |
| Display name | WC26 Stickers |
| Version | from `pubspec.yaml` (`1.0.0+1` → name+build); CI overrides build on package |

Fresh package IDs: sideloaded installs of the old `panini_*` IDs will not upgrade in place.

## Versioning & CI packaging

`pubspec.yaml` uses Flutter’s `name+build` form (e.g. `1.0.0+1`).

| Trigger | What CI does |
|---------|----------------|
| Pull request / push to `main` | Analyze + test only |
| Tag `vX.Y.Z` or `vX.Y.Z+N` | Test → **signed** APK + AAB → GitHub Release |
| Manual `workflow_dispatch` | Test → **signed** APK + AAB (artifacts; no Release unless tagged) |

Store packaging **requires** upload-keystore secrets. CI will **fail** rather than emit a debug-signed AAB.

Artifact names: `wc26-stickers-<name>+<build>.aab` (Play) and matching `.apk` (sideload).

### Required GitHub secrets (Play signing)

| Secret | Purpose |
|--------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the upload `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

Encode locally: `base64 -i upload-keystore.jks | pbcopy`.

Local `make android-aab` may still use debug signing when `android/key.properties` is missing — that path is for developer machines only, not store cuts.

### Play release cut

1. Bump the marketing `version:` **name** in `pubspec.yaml` (e.g. `1.0.1+1`). CI owns a monotonic Play `versionCode` via the run number unless the tag includes `+N`.
2. Commit, then tag and push: `git tag v1.0.1 && git push origin v1.0.1`
3. Wait for CI → GitHub Release.
4. Download `wc26-stickers-*.aab` → Play Console (internal / closed / production track).

## Android Play (console)

1. Create an upload keystore (do **not** commit it):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. For local builds, write `android/key.properties` (gitignored):

   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

3. Prefer CI-signed AAB from a `v*` tag (above). Local: `make android-aab` or `make release` with `key.properties` present.
4. Play Console → Data safety (approx.):
   - No account, no sale of data
   - Camera (optional): album page scan, processed on-device
   - On-device ML Kit text recognition; no cloud OCR
   - Local SQLite collection data only
5. Screenshots: phone + 7" tablet if targeting; feature graphic 1024×500
6. Privacy policy URL: `https://amentilabs.dev/` (or a dedicated policy page)
7. Content rating questionnaire; declare unaffiliated / fan utility

## iOS App Store

IPA builds are **not** in CI yet (needs Apple signing secrets + macOS runner). Ship from a Mac for now:

1. Set `DEVELOPMENT_TEAM` in Xcode for `com.amentilabs.wc26Stickers`
2. Archive / `flutter build ipa --release` (or `make release` on macOS)
3. App Privacy: camera for scanning; data not linked to identity; no tracking
4. Export compliance: `ITSAppUsesNonExemptEncryption` = false (OS TLS only)
5. Privacy Manifest: `ios/Runner/PrivacyInfo.xcprivacy`
6. Review notes: unaffiliated fan sticker tracker; camera optional for Need-list OCR

Future CI (out of scope here): App Store Connect API key, distribution cert / provisioning profile, `ExportOptions.plist`, `DEVELOPMENT_TEAM`.

## Branding / legal

- In-app Settings states the app is not affiliated with Panini or FIFA
- Cover-side art and WC marks: confirm trademark/license before store screenshots that feature them
- Proprietary LICENSE — not open source

## Pre-upload verification

```bash
make ci
# Prefer CI Release AAB. Local check:
make android-aab
unzip -l build/app/outputs/bundle/release/app-release.aab | grep test_fixtures && echo FAIL || echo OK
```
