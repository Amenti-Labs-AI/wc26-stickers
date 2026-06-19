#!/usr/bin/env python3
"""One-time bootstrap: regenerate android/ and ios/ from Flutter SDK templates.

WARNING: Overwrites platform folders. Do not run on a configured project unless
you know you need a full reset. Requires .tools/flutter vendored SDK.
"""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = ROOT / ".tools" / "flutter"
TPL = FLUTTER / "packages" / "flutter_tools" / "templates" / "app"

ANDROID_ID = "com.amentilabs.panini_wc26_tracker"
IOS_ID = "com.amentilabs.paniniWc26Tracker"
PROJECT_NAME = "panini_wc26_tracker"
TITLE = "WC26 Album Tracker"
GRADLE = "8.12"
AGP = "8.9.1"
KOTLIN = "2.1.0"

REPLACEMENTS = {
    "{{androidIdentifier}}": ANDROID_ID,
    "{{projectName}}": PROJECT_NAME,
    "{{titleCaseProjectName}}": TITLE,
    "{{iosIdentifier}}": IOS_ID,
    "{{gradleVersion}}": GRADLE,
    "{{agpVersion}}": AGP,
    "{{kotlinVersion}}": KOTLIN,
}


def subst(text: str) -> str:
    for k, v in REPLACEMENTS.items():
        text = text.replace(k, v)
    # Remove mustache conditional blocks (empty when feature off)
    text = re.sub(r"\{\{#withSwiftPackageManager\}\}.*?\{\{/withSwiftPackageManager\}\}\n?", "", text, flags=re.S)
    text = re.sub(r"\{\{#hasIosDevelopmentTeam\}\}.*?\{\{/hasIosDevelopmentTeam\}\}\n?", "", text, flags=re.S)
    text = re.sub(r"\{\{[^}]+\}\}", "", text)
    return text


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def ensure_platform_symlinks() -> None:
    """Flutter CLI expects legacy paths; canonical deployable source lives under src/."""
    for platform, names in (
        ("ios", ("Runner", "RunnerTests")),
        ("macos", ("Runner", "RunnerTests")),
    ):
        base = ROOT / platform
        src_base = base / "src"
        src_base.mkdir(parents=True, exist_ok=True)
        for name in names:
            legacy = base / name
            canonical = src_base / name
            if legacy.is_dir() and not legacy.is_symlink():
                if canonical.exists():
                    shutil.rmtree(canonical)
                legacy.rename(canonical)
    links = [
        (ROOT / "ios" / "Runner", "src/Runner"),
        (ROOT / "ios" / "RunnerTests", "src/RunnerTests"),
        (ROOT / "android" / "app", "src"),
        (ROOT / "macos" / "Runner", "src/Runner"),
        (ROOT / "macos" / "RunnerTests", "src/RunnerTests"),
    ]
    for link_path, target in links:
        if link_path.exists() or link_path.is_symlink():
            if link_path.is_symlink() and link_path.resolve() == (link_path.parent / target).resolve():
                continue
            if link_path.is_dir() and not link_path.is_symlink():
                continue  # real dir already at canonical path
            link_path.unlink(missing_ok=True)
        link_path.symlink_to(target)


def scaffold_android() -> None:
    android = ROOT / "android"
    app = android / "src"  # deployable module (android/app → src symlink)
    src_android = TPL / "android.tmpl"
    src_kotlin = TPL / "android-kotlin.tmpl"

    # Gradle wrapper
    wrapper_dir = android / "gradle" / "wrapper"
    wrapper_dir.mkdir(parents=True, exist_ok=True)
    props = (src_android / "gradle" / "wrapper" / "gradle-wrapper.properties.tmpl").read_text()
    write_text(wrapper_dir / "gradle-wrapper.properties", subst(props))
    jar_src = FLUTTER / "bin" / "cache" / "artifacts" / "gradle_wrapper" / "gradle" / "wrapper" / "gradle-wrapper.jar"
    shutil.copy2(jar_src, wrapper_dir / "gradle-wrapper.jar")
    for name in ("gradlew", "gradlew.bat"):
        shutil.copy2(
            FLUTTER / "bin" / "cache" / "artifacts" / "gradle_wrapper" / name,
            android / name,
        )
    (android / "gradlew").chmod(0o755)

    write_text(android / "gradle.properties", subst((src_android / "gradle.properties.tmpl").read_text()))
    write_text(android / "settings.gradle.kts", subst((src_android / "settings.gradle.kts.tmpl").read_text()))
    write_text(android / "build.gradle.kts", subst((src_kotlin / "build.gradle.kts.tmpl").read_text()))
    write_text(app / "build.gradle.kts", subst((src_kotlin / "app" / "build.gradle.kts.tmpl").read_text()))

    manifest = subst((src_android / "app" / "src" / "main" / "AndroidManifest.xml.tmpl").read_text())
    camera = (
        '    <uses-permission android:name="android.permission.CAMERA" />\n'
        '    <uses-feature android:name="android.hardware.camera" android:required="false" />\n'
    )
    manifest = manifest.replace("<application", camera + "    <application", 1)
    write_text(app / "src" / "main" / "AndroidManifest.xml", manifest)

    for variant in ("debug", "profile"):
        p = src_android / "app" / "src" / variant / "AndroidManifest.xml.tmpl"
        write_text(app / "src" / variant / "AndroidManifest.xml", subst(p.read_text()))

    kt = subst((src_kotlin / "app" / "src" / "main" / "kotlin" / "androidIdentifier" / "MainActivity.kt.tmpl").read_text())
    write_text(
        app / "src" / "main" / "kotlin" / "com" / "amentilabs" / "panini_wc26_tracker" / "MainActivity.kt",
        kt,
    )

    res_root = src_android / "app" / "src" / "main" / "res"
    for item in res_root.rglob("*"):
        if item.is_file():
            rel = item.relative_to(res_root)
            dest = app / "src" / "main" / "res" / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, dest)

    shutil.copy2(src_android / ".gitignore", android / ".gitignore")
    write_text(
        android / "local.properties.example",
        "# Copy to local.properties and set your Flutter SDK path.\n"
        "flutter.sdk=/path/to/flutter\n"
        "sdk.dir=/path/to/Android/sdk\n",
    )


def tiny_png(path: Path) -> None:
    # Minimal valid 1x1 PNG
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        bytes.fromhex(
            "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
            "0000000a49444154789c6300010000050001080d0d0000000049454e44ae426082"
        )
    )


def scaffold_ios() -> None:
    ios = ROOT / "ios"
    ios_src = ios / "src"
    src_ios = TPL / "ios.tmpl"
    src_swift = TPL / "ios-swift.tmpl"

    def copy_tree(src: Path, dest: Path, skip_suffixes=()) -> None:
        for item in src.rglob("*"):
            if item.is_dir():
                continue
            rel = item.relative_to(src)
            if any(str(rel).endswith(s) for s in skip_suffixes):
                continue
            out = dest / rel
            if item.name.endswith(".img.tmpl"):
                out = out.parent / item.name.replace(".img.tmpl", "")
                tiny_png(out)
                continue
            if item.suffix == ".tmpl":
                out = out.with_suffix("")
                write_text(out, subst(item.read_text()))
            else:
                out.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, out)

    copy_tree(src_ios, ios)

    write_text(ios / "Flutter" / "Debug.xcconfig", '#include "Generated.xcconfig"\n')
    write_text(ios / "Flutter" / "Release.xcconfig", '#include "Generated.xcconfig"\n')
    write_text(
        ios / "Flutter" / "Generated.xcconfig",
        "// Placeholder — run `flutter pub get` to regenerate.\n"
        f"FLUTTER_ROOT=/path/to/flutter\n"
        f"FLUTTER_APPLICATION_PATH={ROOT}\n"
        "COCOAPODS_PARALLEL_CODE_SIGN=true\n"
        "FLUTTER_TARGET=lib/main.dart\n"
        "FLUTTER_BUILD_DIR=build\n"
        "FLUTTER_BUILD_NAME=1.0.0\n"
        "FLUTTER_BUILD_NUMBER=1\n"
        "EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386\n"
        "EXCLUDED_ARCHS[sdk=iphoneos*]=armv7\n"
        "DART_OBFUSCATION=false\n"
        "TRACK_WIDGET_CREATION=true\n"
        "TREE_SHAKE_ICONS=false\n"
        "PACKAGE_CONFIG=.dart_tool/package_config.json\n",
    )

    runner = ios_src / "Runner"
    plist_path = runner / "Info.plist"
    plist = plist_path.read_text()
    if "NSCameraUsageDescription" not in plist:
        insert = (
            "\t<key>NSCameraUsageDescription</key>\n"
            "\t<string>Scan album pages and sticker backs</string>\n"
        )
        plist = plist.replace("</dict>", insert + "</dict>", 1)
        write_text(plist_path, plist)

    shutil.copy2(src_swift / "Runner" / "AppDelegate.swift", runner / "AppDelegate.swift")
    shutil.copy2(src_swift / "Runner" / "Runner-Bridging-Header.h", runner / "Runner-Bridging-Header.h")

    write_text(
        runner / "GeneratedPluginRegistrant.h",
        "#import <Flutter/Flutter.h>\n\n"
        "@interface GeneratedPluginRegistrant : NSObject\n"
        "+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry;\n"
        "@end\n",
    )
    write_text(
        runner / "GeneratedPluginRegistrant.m",
        '#import "GeneratedPluginRegistrant.h"\n\n'
        "@implementation GeneratedPluginRegistrant\n"
        "+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {\n"
        "}\n"
        "@end\n",
    )

    pbx = subst((src_swift / "Runner.xcodeproj" / "project.pbxproj.tmpl").read_text())
    write_text(ios / "Runner.xcodeproj" / "project.pbxproj", pbx)
    scheme = subst((src_swift / "Runner.xcodeproj" / "xcshareddata" / "xcschemes" / "Runner.xcscheme.tmpl").read_text())
    write_text(ios / "Runner.xcodeproj" / "xcshareddata" / "xcschemes" / "Runner.xcscheme", scheme)

    podfile = (FLUTTER / "packages" / "flutter_tools" / "templates" / "cocoapods" / "Podfile-ios-swift").read_text()
    podfile = podfile.replace("# platform :ios, '12.0'", "platform :ios, '15.0'")
    write_text(ios / "Podfile", podfile)

    tests = subst((src_swift / "RunnerTests" / "RunnerTests.swift.tmpl").read_text())
    write_text(ios_src / "RunnerTests" / "RunnerTests.swift", tests)
    shutil.copy2(src_ios / ".gitignore", ios / ".gitignore")


def main() -> None:
    if not FLUTTER.is_dir():
        raise SystemExit(f"Missing Flutter SDK at {FLUTTER}")
    scaffold_android()
    scaffold_ios()
    ensure_platform_symlinks()
    print("Scaffold complete.")


if __name__ == "__main__":
    main()
