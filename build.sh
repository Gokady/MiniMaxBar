#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 用法: ./build.sh [debug|release]   默认 release
#
# 这个脚本是**最终交付**的唯一入口,一次完成:
#   1. 编译
#   2. 拼装 dist/MiniMaxBar.app bundle
#   3. 拷资源(图标、Info.plist)
#   4. ad-hoc 签名
#   5. 清 quarantine
#
# ⚠️ 不要用 `swift build` 单独跑代替这个脚本
#   `swift build` 只产出裸 binary(.build/release/MiniMaxBar),
#   不会更新 dist/MiniMaxBar.app,运行旧 app 看不到任何变化。
#   `swift build` 只适合本地快速 typecheck,不能交付。
# ─────────────────────────────────────────────────────────────

CONFIG="${1:-release}"
APP_NAME="MiniMaxBar"
APP_DIR="dist/${APP_NAME}.app"
DISPLAY_NAME="MiniMax Bar"

# 优先用 Xcode 自带的 swift + macOS 26 SDK(CommandLineTools 不带)
if [ -x "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift" ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    SWIFT="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
else
    SWIFT="$(command -v swift)"
fi

echo "▶ Using swift: $SWIFT"
$SWIFT --version | head -1

echo "▶ swift build -c $CONFIG …"
$SWIFT build -c "$CONFIG"

BIN_PATH="$($SWIFT build -c "$CONFIG" --show-bin-path)/${APP_NAME}"
if [ ! -f "$BIN_PATH" ]; then
    echo "✗ 找不到可执行文件: $BIN_PATH" >&2
    exit 1
fi

echo "▶ 拼装 .app bundle → $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# 拷贝 app 图标(.icns)和状态栏图标(@1x/@2x/@3x PNG)
if [ -f "Icons/AppIcon.icns" ]; then
    cp "Icons/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "  ✓ AppIcon.icns"
fi
# 白色调 template 版
for png in "icon_22.png" "icon_22@2x.png" "icon_22@3x.png"; do
    if [ -f "Icons/statusbar/$png" ]; then
        cp "Icons/statusbar/$png" "$APP_DIR/Contents/Resources/$png"
    fi
done
# 品牌彩色版
for png in "icon_22.png" "icon_22@2x.png" "icon_22@3x.png"; do
    if [ -f "Icons/statusbar/color/$png" ]; then
        mkdir -p "$APP_DIR/Contents/Resources/color"
        cp "Icons/statusbar/color/$png" "$APP_DIR/Contents/Resources/color/$png"
    fi
done

# ad-hoc 签名(本地跑够用,不会被 Gatekeeper 拦截)
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

# 清掉 quarantine 属性(避免 -600 启动错误)
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "✓ 完成: $APP_DIR"
echo "  启动: open $APP_DIR"
