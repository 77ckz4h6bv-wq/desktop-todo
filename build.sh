#!/bin/bash
# 从源码构建「桌面待办.app」（需要 Xcode 命令行工具：xcode-select --install）
set -euo pipefail
cd "$(dirname "$0")"

APP="桌面待办.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

CACHE="${TMPDIR:-/tmp}/todofloat-build"
mkdir -p "$CACHE"
swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 \
  -module-cache-path "$CACHE" \
  src/*.swift -o "$APP/Contents/MacOS/TodoFloat"

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built: $(pwd)/$APP"
echo "把它拖到 ~/Applications 或 /Applications，双击即用；开机自启在菜单栏图标里开。"
