#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AltGesture"
DIST_APP="$ROOT/dist/$APP_NAME.app"
INSTALL_APP="${INSTALL_APP:-$HOME/Applications/$APP_NAME.app}"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/alt-gesture.XXXXXX")"
APP_DIR="$STAGING_ROOT/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BUNDLE_ID="local.alt-gesture"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

trap 'rm -rf "$STAGING_ROOT"' EXIT

cd "$ROOT"
swift build -c release

mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"
if [[ -d "$ROOT/Resources" ]]; then
  ditto --norsrc --noextattr --noqtn "$ROOT/Resources" "$RESOURCES"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Local-only app generated for personal use.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>用于通过 System Events 触发已配置的右键手势快捷键。</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>用于监听右键鼠标手势和 Option 释放事件，不会记录输入内容。</string>
  <key>NSScreenCaptureDescription</key>
  <string>用于显示窗口缩略图，不会上传或保存屏幕内容。</string>
</dict>
</plist>
PLIST

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/"[^"]+"/ { print $2; exit }')"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

xattr -cr "$APP_DIR"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DIST_APP"
mkdir -p "$(dirname "$DIST_APP")"
ditto --norsrc --noextattr --noqtn "$APP_DIR" "$DIST_APP"

rm -rf "$INSTALL_APP"
mkdir -p "$(dirname "$INSTALL_APP")"
ditto --norsrc --noextattr --noqtn "$APP_DIR" "$INSTALL_APP"
codesign --verify --deep --strict --verbose=2 "$INSTALL_APP"

echo "$INSTALL_APP"
