#!/bin/bash
# ============================================================
#  QtEasyTier macOS 安装脚本(免 Apple 公证方案)
# ------------------------------------------------------------
#  为什么需要这个脚本?
#  QtEasyTier 的 TUN 组网功能依赖一个需要管理员权限(root)运行
#  的辅助程序 QtEasyTierHelper。由于本应用未做 Apple 公证(付费),
#  从网上下载的 .app 会带有"隔离 + 来源追踪(provenance)"标记。
#  实测(macOS 26)结论:
#    1. 普通双击会被 Gatekeeper 拦截(且新版 macOS 已取消"右键打开");
#    2. 即使去掉隔离标记,只要 .app 是"下载来的",其内部以 root 运行
#       的 helper 仍会被 AMFI 拒绝(错误 -423),导致 TUN 起不来;
#    3. 关键:装到系统级 /Applications 会触发更严策略,helper 照样被拦;
#       装到用户级 ~/Applications 则一切正常。
#  因此本脚本的做法是:用 ditto 把 .app 重建到 ~/Applications
#  (切断下载来源追踪)→ 清除隔离属性 → 本机重新 ad-hoc 签名。
#  这样无需付费公证,即可让 GUI 和需要提权的 helper 都正常工作。
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_APP="$SCRIPT_DIR/QtEasyTier.app"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/QtEasyTier.app"

echo "=================================================="
echo "  QtEasyTier 安装程序(免公证方案)"
echo "=================================================="
echo ""

if [ ! -d "$SRC_APP" ]; then
    echo "❌ 未在脚本所在目录找到 QtEasyTier.app"
    echo "   请确认本脚本与 QtEasyTier.app 在同一文件夹(DMG)中。"
    echo ""
    read -p "按回车键退出..." _ || true
    exit 1
fi

echo "→ 关闭可能在运行的旧实例..."
pkill -f 'QtEasyTier.app/Contents/MacOS/QtEasyTier' 2>/dev/null || true

echo "→ 重建并安装到 ~/Applications(切断下载来源标记)..."
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
# ditto 重建是关键:生成全新 inode,切断 provenance / quarantine 追踪
ditto "$SRC_APP" "$DEST"

echo "→ 清除隔离与来源扩展属性..."
xattr -cr "$DEST" 2>/dev/null || true

echo "→ 本机重新 ad-hoc 签名(从内层二进制到主程序)..."
codesign --force --sign - "$DEST/Contents/MacOS/QtEasyTierHelper"  2>/dev/null || true
codesign --force --sign - "$DEST/Contents/MacOS/CIDRCalculator"    2>/dev/null || true
codesign --force --deep --sign - "$DEST"                           2>/dev/null || true

echo ""
echo "✅ 安装完成!位置:$DEST"
echo "   可从「启动台」或 ~/Applications 打开 QtEasyTier。"
echo "   首次使用 TUN 组网时会弹出一次管理员密码授权,属正常现象。"
echo ""
echo "→ 是否现在打开 QtEasyTier?[Y/n]"
read -r ANS || true
case "${ANS:-Y}" in
    [nN]*) echo "已安装,稍后可自行打开。" ;;
    *)     open "$DEST" ;;
esac

echo ""
read -p "按回车键退出..." _ || true
