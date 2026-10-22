#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p outputs work
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_ROOT/.build/module-cache"
TASK_SWIFT_FLAGS=(--disable-sandbox --cache-path "$TASK_ROOT/.build/cache" --config-path "$TASK_ROOT/.build/config" --security-path "$TASK_ROOT/.build/security")
swift build "${TASK_SWIFT_FLAGS[@]}" -c release --arch arm64 --arch x86_64
TASK_BIN_DIR="$(swift build "${TASK_SWIFT_FLAGS[@]}" -c release --arch arm64 --arch x86_64 --show-bin-path)"
TASK_APP="$TASK_ROOT/outputs/BKCleanHelper.app"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
cp "$TASK_BIN_DIR/BKCleanHelper" "$TASK_APP/Contents/MacOS/BKCleanHelper"
cp Resources/Info.plist "$TASK_APP/Contents/Info.plist"
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" scripts/Icon.swift -o work/generate-icon
work/generate-icon work/AppIcon.iconset
python3 scripts/package_icon.py work/AppIcon.iconset "$TASK_APP/Contents/Resources/AppIcon.icns"
xattr -cr "$TASK_APP"
codesign --force --sign - --identifier io.github.binbinku.BKCleanHelper "$TASK_APP"
codesign --verify --deep --strict "$TASK_APP"
TASK_VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
TASK_ZIP="BKCleanHelper-$TASK_VERSION.zip"
rm -f "$TASK_ROOT/outputs/$TASK_ZIP"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$TASK_APP" "$TASK_ROOT/outputs/$TASK_ZIP"
(cd "$TASK_ROOT/outputs" && shasum -a 256 "$TASK_ZIP" > "$TASK_ZIP.sha256")
cp README.md "$TASK_ROOT/outputs/使用说明.md"
mkdir -p work/BKCleanHelper-Source
cp Package.swift README.md .gitignore work/BKCleanHelper-Source/
cp -R Sources Tests Resources scripts work/BKCleanHelper-Source/
ditto -c -k --keepParent work/BKCleanHelper-Source "$TASK_ROOT/outputs/BKCleanHelper-Source.zip"
echo "已构建：$TASK_APP"
echo "发布包：$TASK_ROOT/outputs/$TASK_ZIP"
