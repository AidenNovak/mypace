#!/bin/bash
#
# build-app.sh · v0.2
# ==================================================
# 把 Preview/*.swift 多文件源代码打包成 .app + .dmg。
# 不需要 Xcode，纯 swiftc + shell。
#

set -e

APP_NAME="MyPace Preview"
BUNDLE_ID="ai.mypace.preview"
VERSION="0.8.0"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
DMG_NAME="MyPace-Preview-${VERSION}.dmg"

echo "──────────────────────────────────────────"
echo "  Building ${APP_NAME} v${VERSION}"
echo "──────────────────────────────────────────"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 1) 编译多文件
echo "▶ Compiling 6 Swift source files…"
xcrun -sdk macosx swiftc \
  -parse-as-library \
  -target arm64-apple-macos14.0 \
  -framework Cocoa \
  -framework AVFoundation \
  -O \
  Preview/Logger.swift \
  Preview/Models.swift \
  Preview/Settings.swift \
  Preview/L10n.swift \
  Preview/ScriptStore.swift \
  Preview/ASR.swift \
  Preview/Recording.swift \
  Preview/RhythmPlayback.swift \
  Preview/WelcomeWindow.swift \
  Preview/PreferencesWindow.swift \
  Preview/ControlBar.swift \
  Preview/WordRunView.swift \
  Preview/MyPacePreview.swift \
  -o "$APP_DIR/Contents/MacOS/MyPacePreview"

echo "  Binary: $(du -h "$APP_DIR/Contents/MacOS/MyPacePreview" | awk '{print $1}')"

# 2) 拷贝 App 图标到 Resources
if [ -f "Resources/AppIcon.icns" ]; then
    echo "▶ Embedding App icon…"
    cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# 3) Info.plist （含必要权限声明 + 图标引用）
echo "▶ Writing Info.plist…"
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>MyPacePreview</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>MyPace 需要使用麦克风录制你的练习音频，用于生成节奏映射。音频只在本机暂存，对齐完成后保留 7 天后自动删除。</string>
</dict>
</plist>
EOF

# 3) ad-hoc 签名
echo "▶ Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true

# 4) 验证
echo "▶ Bundle:"
ls -lh "$APP_DIR/Contents/MacOS/" | head -3

# 5) 打 DMG
echo "▶ Creating DMG…"
DMG_TEMP="$BUILD_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_DIR" "$DMG_TEMP/"

ln -s /Applications "$DMG_TEMP/Applications" 2>/dev/null || true

if [ -f "VLOGGER-README.md" ]; then
    cp VLOGGER-README.md "$DMG_TEMP/README.md"
fi

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDZO \
  "$BUILD_DIR/$DMG_NAME" 2>&1 | tail -2

echo ""
echo "──────────────────────────────────────────"
echo "✅ Done · v${VERSION}"
echo "──────────────────────────────────────────"
echo "  App:  $APP_DIR ($(du -sh "$APP_DIR" | awk '{print $1}'))"
echo "  DMG:  $BUILD_DIR/$DMG_NAME ($(du -h "$BUILD_DIR/$DMG_NAME" | awk '{print $1}'))"
echo "──────────────────────────────────────────"
