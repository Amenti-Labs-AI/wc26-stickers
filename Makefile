# WC26 Album Tracker — dev entry point. Run `make` or `make help`.
.DEFAULT_GOAL := help

IOS_SIMULATOR ?= iPhone 17 Pro
export IOS_SIMULATOR

.PHONY: help get test analyze ci scan-check scan-check-device ios device android android-device android-devices android-pull-db android-push-db android-screenshot ios-screenshot \
        android-apk android-apk-release android-install android-install-release release \
        clean generate-catalog generate-templates

help: ## Show dev commands
	@printf "\nWC26 Album Tracker\n\n"
	@printf "  Flutter\n"
	@printf "    make get              flutter pub get\n"
	@printf "    make test             flutter test\n"
	@printf "    make scan-check       scan pipeline tests + fixture (run before deploy)\n"
	@printf "    make scan-check-device  portrait OCR tests on USB Android/iOS\n"
	@printf "    make scan-check-device-mex  MEX-only device OCR loop\n"
	@printf "    make analyze          flutter analyze\n"
	@printf "    make ci               analyze + test\n"
	@printf "    make ios              iOS Simulator (collection; Scan → pick photo)\n"
	@printf "    make device           physical iPhone (camera scan)\n"
	@printf "    make android          Android device or emulator\n"
	@printf "    make android-device   physical Android only (Pixel 4a / stock Android)\n"
	@printf "    make android-devices  list adb + flutter devices\n"
	@printf "    make android-pull-db  pull device SQLite → data/device/\n"
	@printf "    make android-push-db  push data/device/ SQLite → device\n"
	@printf "    make android-screenshot  capture Android screen → docs/screenshots/\n"
	@printf "    make ios-screenshot     capture iOS screen → docs/screenshots/\n"
	@printf "    make android-apk      build debug APK\n"
	@printf "    make android-install  build debug APK + adb install\n"
	@printf "    make release          test + release APK (+ IPA on macOS)\n"
	@printf "\n  Assets (rare)\n"
	@printf "    make generate-catalog\n"
	@printf "    make generate-templates\n"
	@printf "\n  Manual flutter: source ios/scripts/env.sh\n\n"

get: ## flutter pub get
	flutter pub get

test: get ## flutter test
	flutter test

analyze: ## flutter analyze
	flutter analyze

ci: analyze test ## CI checks

scan-check: get ## Validate scan pipeline on host (~15s, no device)
	@flutter test test/camera_preview_mapper_test.dart \
		test/camera_frame_convert_test.dart \
		test/page_template_matcher_test.dart \
		test/sticker_code_parser_test.dart \
		test/scanned_missing_test.dart test/portrait_text_matcher_test.dart \
		test/portrait_ocr_strategy_test.dart test/ocr_label_rescue_test.dart \
		test/ocr_overlay_builder_test.dart test/portrait_slot_from_read_test.dart \
		test/live_overlay_tracker_test.dart test/team_code_ocr_aliases_test.dart \
		test/ocr_live_frame_test.dart test/missing_scan_filter_test.dart \
		test/scan_engine_test.dart
	@echo "scan-check passed — safe to deploy scan changes"

scan-check-device: get ## Portrait OCR on physical device — MEX + QAT + FWC (ML Kit)
	@device=$$(flutter devices --machine | python3 -c "import json,sys; d=[x for x in json.load(sys.stdin) if x.get('emulator') is False and x.get('isSupported') and ('android' in (x.get('targetPlatform') or '') or 'ios' in (x.get('targetPlatform') or ''))]; print(d[0]['id'] if d else '')"); \
	if [ -z "$$device" ]; then echo "No physical Android/iOS device found"; exit 1; fi; \
	flutter test integration_test/portrait_ocr_strategy_test.dart -d "$$device"

scan-check-device-mex: get ## Quick device loop — MEX group only
	@device=$$(flutter devices --machine | python3 -c "import json,sys; d=[x for x in json.load(sys.stdin) if x.get('emulator') is False and x.get('isSupported') and ('android' in (x.get('targetPlatform') or '') or 'ios' in (x.get('targetPlatform') or ''))]; print(d[0]['id'] if d else '')"); \
	if [ -z "$$device" ]; then echo "No physical Android/iOS device found"; exit 1; fi; \
	flutter test integration_test/portrait_ocr_strategy_test.dart -d "$$device" --name "MEX"

ios: ## iOS Simulator
	./ios/scripts/run_simulator.sh

device: ## physical iPhone / iPad
	./ios/scripts/run_device.sh

android: ## Android device or emulator
	./android/scripts/run.sh

android-device: ## physical Android (USB / adb)
	./android/scripts/run_device.sh

android-device-fresh: ## clean + physical Android deploy (guaranteed full rebuild)
	flutter clean
	./android/scripts/run_device.sh

android-devices: ## list adb + flutter devices
	./android/scripts/devices.sh

android-pull-db: ## pull panini_wc26.db from USB device → data/device/
	bash android/scripts/pull_db.sh

android-push-db: ## push data/device/panini_wc26.db → USB device (overwrites)
	bash android/scripts/push_db.sh

android-screenshot: ## adb screencap → docs/screenshots/NAME.png (NAME=home)
	bash android/scripts/screenshot.sh $(or $(NAME),capture)

ios-screenshot: ## Simulator or iPhone → docs/screenshots/NAME.png (NAME=home)
	bash ios/scripts/screenshot.sh $(or $(NAME),capture)

android-apk: ## build debug APK → build/app/outputs/flutter-apk/
	BUILD=debug ./android/scripts/build_apk.sh

android-apk-release: ## build release APK
	BUILD=release ./android/scripts/build_apk.sh

android-install: ## build debug APK + adb install -r
	BUILD=debug ./android/scripts/install_apk.sh

android-install-release: ## build release APK + adb install -r
	BUILD=release ./android/scripts/install_apk.sh

release: ## release APK (+ IPA on macOS)
	flutter pub get
	flutter test
	flutter build apk --release
	@if [ "$$(uname -s)" = "Darwin" ]; then flutter build ipa --release; \
	else echo "Skipping IPA (macOS only)"; fi

clean: ## placeholder for future cleanup targets
	@echo "Nothing to clean."

generate-catalog: ## regenerate assets/catalog/wc26_catalog.json
	python3 tooling/generate_catalog.py

generate-templates: ## regenerate assets/page_templates/
	python3 tooling/generate_page_templates.py
