#!/bin/bash
# ============================================================
#  QtEasyTier macOS 一键安装(免 Apple 公证)
# ------------------------------------------------------------
#  用法(在「终端」中粘贴执行):
#    curl -fsSL https://raw.githubusercontent.com/dwgx/qt-easy-tier/helper-on-latest/package/mac/web_install.sh | bash
#
#  为什么用终端而不是双击安装?
#  本应用未做 Apple 付费公证。新版 macOS(15/26)对"下载来的"
#  未公证程序拦得很严:双击 .app 或 .command 都会被 Gatekeeper 挡下,
#  且已取消"右键打开"绕过。而在终端里执行的脚本不经过这层拦截。
#  本脚本会:下载 DMG → 用 ditto 重建到 ~/Applications(切断下载
#  来源追踪)→ 清隔离属性 → 本机重新 ad-hoc 签名。这样 GUI 和需要
#  管理员权限的 TUN 辅助程序(QtEasyTierHelper)都能正常运行。
#  注:必须装到用户级 ~/Applications;实测装到系统级 /Applications
#  会触发更严策略导致 helper 被拒(错误 -423)。
# ============================================================
set -e

REPO="dwgx/qt-easy-tier"
TAG="${QET_TAG:-v2.1.2-macos-helper}"
DMG_NAME="QtEasyTier_v2.1.2_macos_arm64_helper.dmg"
DMG_URL="https://github.com/$REPO/releases/download/$TAG/$DMG_NAME"

DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/QtEasyTier.app"
TMP="$(mktemp -d /tmp/qet-install.XXXXXX)"
MP="$TMP/mnt"

cleanup() {
    [ -d "$MP" ] && hdiutil detach "$MP" -force >/dev/null 2>&1 || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "=================================================="
echo "  QtEasyTier 一键安装(免公证方案)"
echo "=================================================="

if [ "$(uname -m)" != "arm64" ]; then
    echo "⚠️  当前构建为 Apple Silicon(arm64)。你的机器架构为 $(uname -m),可能无法运行。"
fi

echo "→ 下载 DMG..."
echo "   $DMG_URL"
curl -fL --progress-bar -o "$TMP/$DMG_NAME" "$DMG_URL"

echo "→ 挂载 DMG..."
mkdir -p "$MP"
hdiutil attach "$TMP/$DMG_NAME" -nobrowse -mountpoint "$MP" >/dev/null

SRC_APP="$MP/QtEasyTier.app"
if [ ! -d "$SRC_APP" ]; then
    echo "❌ DMG 内未找到 QtEasyTier.app"
    exit 1
fi

echo "→ 关闭可能在运行的旧实例..."
pkill -f 'QtEasyTier.app/Contents/MacOS/QtEasyTier' 2>/dev/null || true

echo "→ 重建并安装到 ~/Applications(切断下载来源标记)..."
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
ditto "$SRC_APP" "$DEST"

echo "→ 清除隔离与来源扩展属性..."
xattr -cr "$DEST" 2>/dev/null || true

echo "→ 本机重新 ad-hoc 签名..."
codesign --force --sign - "$DEST/Contents/MacOS/QtEasyTierHelper"  2>/dev/null || true
codesign --force --sign - "$DEST/Contents/MacOS/CIDRCalculator"    2>/dev/null || true
codesign --force --deep --sign - "$DEST"                           2>/dev/null || true

echo ""
echo "✅ 安装完成!位置:$DEST"
echo "   已从「启动台」或 ~/Applications 即可打开 QtEasyTier。"
echo "   首次使用 TUN 组网会弹出一次管理员授权,属正常现象。"
echo ""
echo "→ 正在打开 QtEasyTier..."
open "$DEST" || true
