#!/bin/bash
#
# build-app.sh · MyPace v0.8
# ==================================================
# 把 Preview/*.swift 打包成 .app + .dmg
# 支持两种模式：
#   1. 默认：ad-hoc 签名（本地测试用）
#   2. 正式：Developer ID 签名 + notarization（发版用）
#
# 正式发版前请先配置好 Apple Developer ID 证书。
#
# 用法：
#   ./build-app.sh                    # ad-hoc（默认）
#   ./build-app.sh notarize           # Developer ID + 公证（需提前配置环境变量）
#
# 需要的环境变量（正式模式）：
#   DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
#   TEAM_ID="YOUR10CHARTEAMID"
#   NOTARY_KEYCHAIN_PROFILE="MyPaceNotary"   # 通过 notarytool store-credentials 提前创建
#
set -e

APP_NAME="MyPace Preview"
BUNDLE_ID="ai.mypace.preview"
VERSION="0.9.2"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
DMG_NAME="MyPace-Preview-${VERSION}.dmg"

MODE="${1:-adhoc}"

echo "──────────────────────────────────────────"
echo "  Building ${APP_NAME} v${VERSION}  (mode: ${MODE})"
echo "──────────────────────────────────────────"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 1) 编译（AppKit + CoreAnimation 版）
echo "▶ Compiling..."
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

echo "  Binary size: $(du -h "$APP_DIR/Contents/MacOS/MyPacePreview" | awk '{print $1}')"

# 2) 资源
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# 3) Info.plist
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
    <string>MyPace 需要使用麦克风录制你的练习音频，用于生成节奏映射。音频只存在你 mac 的本地目录，永远不会上云。</string>
</dict>
</plist>
EOF

# 4) 代码签名
if [ "$MODE" = "notarize" ] || [ "$MODE" = "sign" ]; then
    if [ -z "$DEVELOPER_ID_APP" ]; then
        echo "❌ 错误：正式签名模式需要设置环境变量 DEVELOPER_ID_APP"
        echo "   示例：export DEVELOPER_ID_APP=\"Developer ID Application: Your Name (TEAMID)\""
        exit 1
    fi

    echo "▶ Code signing with Developer ID..."
    codesign --force --deep --options runtime --sign "$DEVELOPER_ID_APP" "$APP_DIR"

    echo "✅ 签名完成（包含 hardened runtime）"
else
    echo "▶ Code signing (ad-hoc)..."
    codesign --force --deep --sign - "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true
fi

# 5) 验证
echo "▶ Verifying bundle..."
codesign -dv --verbose=4 "$APP_DIR" 2>&1 | head -10 || true

# 6) 打包 DMG
echo "▶ Creating DMG..."
DMG_TEMP="$BUILD_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

cp -R "$APP_DIR" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications" 2>/dev/null || true

# 把给 vlogger 的说明文档放进 DMG 根目录
if [ -f "VLOGGER-README.md" ]; then
    cp VLOGGER-README.md "$DMG_TEMP/README.md"
fi

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDZO \
  "$BUILD_DIR/$DMG_NAME" 2>&1 | tail -3

echo ""
echo "──────────────────────────────────────────"
echo "✅ Build complete · v${VERSION} (${MODE})"
echo "──────────────────────────────────────────"
echo "  App:  $APP_DIR"
echo "  DMG:  $BUILD_DIR/$DMG_NAME"
echo "──────────────────────────────────────────"

# 7) 如果是 notarize 模式，给出后续公证命令提示
if [ "$MODE" = "notarize" ]; then
    echo ""
    echo "下一步：公证（notarization）"
    echo "请运行以下命令（需提前配置 notarytool 凭证）："
    echo ""
    echo "  xcrun notarytool submit \"$BUILD_DIR/$DMG_NAME\" \\"
    echo "    --keychain-profile \"\$NOTARY_KEYCHAIN_PROFILE\" \\"
    echo "    --team-id \"\$TEAM_ID\" \\"
    echo "    --wait"
    echo ""
    echo "公证成功后打钉："
    echo "  xcrun stapler staple \"$BUILD_DIR/$DMG_NAME\""
    echo ""
fi
