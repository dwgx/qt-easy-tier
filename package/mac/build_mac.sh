#!/bin/bash
set -e

PROJECT_DIR="${1:-$(pwd)}"
VERSION="${2:-}"

# 从 CMakeLists.txt 提取版本号
if [ -z "$VERSION" ]; then
    CMAKE_FILE="$PROJECT_DIR/CMakeLists.txt"
    if [ ! -f "$CMAKE_FILE" ]; then
        echo "错误: 未找到 CMakeLists.txt: $CMAKE_FILE"
        exit 1
    fi
    VERSION=$(sed -nE 's/.*project\([^)]*VERSION ([0-9.]+).*/\1/p' "$CMAKE_FILE" || true)
    if [ -z "$VERSION" ]; then
        echo "错误: 无法从 CMakeLists.txt 提取版本号"
        exit 1
    fi
    echo "从 CMakeLists.txt 提取版本号: $VERSION"
fi

echo "=============================="
echo "版本号: $VERSION"
echo "项目目录: $PROJECT_DIR"
echo "=============================="

APP_NAME="QtEasyTier"
APP_PATH="$PROJECT_DIR/Install/${APP_NAME}.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_NAME"
CIDR_EXECUTABLE="$APP_PATH/Contents/MacOS/CIDRCalculator"
HELPER_EXECUTABLE="$APP_PATH/Contents/MacOS/QtEasyTierHelper"
APP_FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
SVG_ICON_PLUGIN="$APP_PATH/Contents/PlugIns/iconengines/libqsvgicon.dylib"
SVG_IMAGE_PLUGIN="$APP_PATH/Contents/PlugIns/imageformats/libqsvg.dylib"
SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:--}"
COMMUNITY_BUILD="${MACOS_COMMUNITY_BUILD:-0}"

if [ ! -d "$APP_PATH" ]; then
    echo "错误: 未找到 .app Bundle: $APP_PATH"
    echo "请先运行 cmake --install 生成 Bundle"
    exit 1
fi

if [ ! -x "$APP_EXECUTABLE" ]; then
    echo "错误: 未找到可执行文件: $APP_EXECUTABLE"
    exit 1
fi

if [ ! -x "$CIDR_EXECUTABLE" ]; then
    echo "错误: 未找到CIDRCalculator辅助程序: $CIDR_EXECUTABLE"
    exit 1
fi

if [ ! -x "$HELPER_EXECUTABLE" ]; then
    echo "错误: 未找到QtEasyTierHelper辅助程序: $HELPER_EXECUTABLE"
    exit 1
fi

if [ "$COMMUNITY_BUILD" = "1" ] && strings "$HELPER_EXECUTABLE" | grep -q 'QTEASYTIER_PROTOTYPE_HELPER_DISABLED'; then
    echo "错误: macOS community build 需要启用 prototype helper"
    echo "请使用 -DQTEASYTIER_ENABLE_PROTOTYPE_HELPER=ON 重新配置并构建"
    exit 1
fi

ARCH=$(lipo -archs "$APP_EXECUTABLE" | tr ' ' '-' || true)
if [ -z "$ARCH" ]; then
    echo "错误: 无法读取 app 架构: $APP_EXECUTABLE"
    exit 1
fi

if [ ! -f "$APP_FRAMEWORKS_DIR/libeasytier_ffi.dylib" ]; then
    echo "错误: 未找到已打包的 EasyTier FFI 动态库: $APP_FRAMEWORKS_DIR/libeasytier_ffi.dylib"
    exit 1
fi

if ! find "$APP_FRAMEWORKS_DIR" -maxdepth 1 -name 'Qt*.framework' -type d | grep -q .; then
    echo "错误: 未找到 Qt Frameworks。请确保 cmake --install 成功运行 macdeployqt 后再创建 DMG。"
    exit 1
fi

for SVG_PLUGIN in "$SVG_ICON_PLUGIN" "$SVG_IMAGE_PLUGIN"; do
    if [ ! -f "$SVG_PLUGIN" ]; then
        echo "错误: 未找到SVG插件: $SVG_PLUGIN。请确认已安装qtsvg并重新运行cmake --install。"
        exit 1
    fi
done

is_macho_file() {
    file "$1" | grep -q 'Mach-O'
}

bundle_dependency_ref() {
    local dep="$1"
    if [[ "$dep" == *".framework/"* ]]; then
        printf '%s\n' "$dep" | sed -E 's|^.*\/([^\/]+\.framework\/.*)$|@rpath/\1|'
    else
        printf '@rpath/%s\n' "$(basename "$dep")"
    fi
}

macho_install_name() {
    otool -D "$1" 2>/dev/null | awk '
        NR == 1 { next }
        /:$/ { next }
        NF { print; exit }
    '
}

fix_local_dependency_paths() {
    local scan_root="$1"
    local macho install_name refs dep new_ref

    while IFS= read -r -d '' macho; do
        if ! is_macho_file "$macho"; then
            continue
        fi

        install_name=$(macho_install_name "$macho" || true)
        if [ -n "$install_name" ] && printf '%s\n' "$install_name" | grep -Eq '/opt/homebrew|/usr/local|/Users/'; then
            new_ref=$(bundle_dependency_ref "$install_name")
            echo "修正 install name: $macho"
            echo "  $install_name -> $new_ref"
            install_name_tool -id "$new_ref" "$macho"
        fi

        refs=$(otool -L "$macho" 2>/dev/null \
            | awk 'substr($0, 1, 1) == "\t" { print $1 }' \
            | grep -E '/opt/homebrew|/usr/local|/Users/' || true)

        while IFS= read -r dep; do
            if [ -z "$dep" ]; then
                continue
            fi
            new_ref=$(bundle_dependency_ref "$dep")
            echo "修正依赖引用: $macho"
            echo "  $dep -> $new_ref"
            install_name_tool -change "$dep" "$new_ref" "$macho"
        done <<< "$refs"
    done < <(find "$scan_root" -type f -print0)
}

check_no_local_dependency_paths() {
    local scan_root="$1"
    local bad_deps=0
    local macho install_name refs

    while IFS= read -r -d '' macho; do
        if ! is_macho_file "$macho"; then
            continue
        fi

        install_name=$(macho_install_name "$macho" || true)
        if [ -n "$install_name" ] && printf '%s\n' "$install_name" | grep -Eq '/opt/homebrew|/usr/local|/Users/'; then
            echo "错误: app Mach-O 文件包含本机绝对 install name: $macho"
            printf '%s\n' "$install_name"
            bad_deps=1
        fi

        refs=$(otool -L "$macho" \
            | awk 'substr($0, 1, 1) == "\t" { print $1 }' \
            | grep -E '/opt/homebrew|/usr/local|/Users/' || true)
        if [ -n "$refs" ]; then
            echo "错误: app Mach-O 文件包含本机绝对动态库路径: $macho"
            printf '%s\n' "$refs"
            bad_deps=1
        fi
    done < <(find "$scan_root" -type f -print0)

    return "$bad_deps"
}

fix_local_dependency_paths "$APP_PATH"

if ! check_no_local_dependency_paths "$APP_PATH"; then
    exit 1
fi

echo "签名 app bundle..."
if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --deep --sign - "$APP_PATH"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

if ! codesign --verify --deep --strict --verbose=2 "$APP_PATH"; then
    echo "错误: app 签名校验失败，请先重新运行 cmake --install"
    exit 1
fi

DMG_SUFFIX=""
if [ "$COMMUNITY_BUILD" = "1" ]; then
    DMG_SUFFIX="_community"
fi
DMG_NAME="${APP_NAME}_v${VERSION}_macos_${ARCH}${DMG_SUFFIX}"
DMG_PATH="$PROJECT_DIR/Install/${DMG_NAME}.dmg"

echo "创建 DMG 镜像..."

# 组装 DMG 内容到 staging 目录:app + 安装脚本 + Applications 软链 + 说明
SCRIPT_DIR_BM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_STAGE="$(mktemp -d /tmp/qet-dmg.XXXXXX)"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
if [ -f "$SCRIPT_DIR_BM/install_qet.command" ]; then
    cp "$SCRIPT_DIR_BM/install_qet.command" "$DMG_STAGE/install_qet.command"
    chmod +x "$DMG_STAGE/install_qet.command"
fi
cat > "$DMG_STAGE/请先阅读.txt" <<'READMETXT'
QtEasyTier macOS 安装说明(免 Apple 公证)
============================================

本应用未做 Apple 付费公证。新版 macOS(15/26)对“下载来的”未公证
程序拦得很严:直接把 QtEasyTier.app 拖进 /Applications 后双击,会被
Gatekeeper 拦截;而且需要管理员权限的 TUN 组网辅助程序也会被系统
拒绝运行,导致组网功能用不了。

请按下面任一方式安装(二选一):

【方式一 · 推荐 · 终端一键安装】
  打开“终端”(在“启动台”里搜索 Terminal),粘贴下面这行并回车:

  curl -fsSL https://raw.githubusercontent.com/dwgx/qt-easy-tier/helper-on-latest/package/mac/web_install.sh | bash

  它会自动下载、正确安装到 ~/Applications 并打开。

【方式二 · 用本 DMG 内的安装脚本】
  1. 打开“终端”(启动台里搜索 Terminal);
  2. 把本窗口里的 install_qet.command 拖进终端窗口,回车执行
     (直接双击会被 Gatekeeper 拦,所以要在终端里跑);
  3. 按提示完成,程序会装到 ~/Applications。

为什么不能直接拖进 /Applications?
  实测(macOS 26):安装到系统级 /Applications 会触发更严格的安全策略,
  使需要管理员权限的辅助程序被拒(错误 -423),TUN 组网起不来。
  安装到用户级 ~/Applications 则一切正常,应用照样出现在“启动台”。
READMETXT

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGE"

echo "=============================="
echo "DMG 创建完成!"
echo "输出: $DMG_PATH"
echo "=============================="

