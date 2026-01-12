#!/bin/bash

# Better Voice Input 打包脚本
# 用法: ./scripts/package.sh [--notarize]

set -e

# 配置
APP_NAME="Better Voice Input"
BUNDLE_ID="com.bvi.app"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="BetterVoiceInput-$VERSION.dmg"
OUTPUT_DIR="dist"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."

    if ! command -v swift &> /dev/null; then
        log_error "未找到 swift 命令"
        exit 1
    fi

    if ! command -v create-dmg &> /dev/null; then
        log_warn "未找到 create-dmg，将使用 hdiutil 创建简单 DMG"
        log_warn "如需美观的 DMG，请安装: brew install create-dmg"
    fi
}

# 构建 Release 版本
build_app() {
    log_info "构建 Release 版本..."
    swift build -c release --product BetterVoiceInputApp
}

# 创建 .app 包结构
create_app_bundle() {
    log_info "创建应用包结构..."

    # 清理旧的 app 包
    rm -rf "$APP_DIR"

    # 创建目录结构
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"

    # 复制可执行文件
    cp "$BUILD_DIR/BetterVoiceInputApp" "$APP_DIR/Contents/MacOS/"

    # 复制 Info.plist
    if [ -f "Sources/BetterVoiceInputApp/Info.plist" ]; then
        cp "Sources/BetterVoiceInputApp/Info.plist" "$APP_DIR/Contents/"
    else
        log_error "Info.plist 未找到"
        exit 1
    fi

    # 复制图标（如果存在）
    if [ -f "Resources/AppIcon.icns" ]; then
        cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    else
        log_warn "应用图标未找到 (Resources/AppIcon.icns)，使用默认图标"
    fi

    # 创建 PkgInfo
    echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

    log_info "应用包创建完成: $APP_DIR"
}

# 代码签名
sign_app() {
    log_info "代码签名..."

    # 检查是否有开发者证书
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')

    if [ -z "$IDENTITY" ]; then
        log_warn "未找到 Developer ID 证书，使用临时签名"
        codesign --force --deep --sign - "$APP_DIR"
    else
        log_info "使用证书: $IDENTITY"

        # 签名应用
        if [ -f "Sources/BetterVoiceInputApp/BetterVoiceInputApp.entitlements" ]; then
            codesign --force --deep --options runtime \
                --entitlements "Sources/BetterVoiceInputApp/BetterVoiceInputApp.entitlements" \
                --sign "$IDENTITY" \
                "$APP_DIR"
        else
            codesign --force --deep --options runtime \
                --sign "$IDENTITY" \
                "$APP_DIR"
        fi

        # 验证签名
        codesign --verify --verbose "$APP_DIR"
    fi

    log_info "代码签名完成"
}

# 创建 DMG
create_dmg() {
    log_info "创建 DMG..."

    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"

    # 删除旧的 DMG
    rm -f "$OUTPUT_DIR/$DMG_NAME"

    # 尝试使用 create-dmg 创建美观的 DMG
    if command -v create-dmg &> /dev/null; then
        # 检查是否有图标
        ICON_ARGS=""
        if [ -f "Resources/AppIcon.icns" ]; then
            ICON_ARGS="--volicon Resources/AppIcon.icns"
        fi

        create-dmg \
            --volname "$APP_NAME" \
            $ICON_ARGS \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 150 190 \
            --hide-extension "$APP_NAME.app" \
            --app-drop-link 450 190 \
            --no-internet-enable \
            "$OUTPUT_DIR/$DMG_NAME" \
            "$APP_DIR" \
            2>/dev/null || {
                log_warn "create-dmg 失败，使用 hdiutil 创建简单 DMG"
                create_simple_dmg
            }
    else
        create_simple_dmg
    fi

    log_info "DMG 创建完成: $OUTPUT_DIR/$DMG_NAME"
}

# 创建简单 DMG (使用 hdiutil)
create_simple_dmg() {
    # 创建临时目录
    TEMP_DMG_DIR=$(mktemp -d)
    cp -r "$APP_DIR" "$TEMP_DMG_DIR/"

    # 创建 Applications 快捷方式
    ln -s /Applications "$TEMP_DMG_DIR/Applications"

    # 创建 DMG
    hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$OUTPUT_DIR/$DMG_NAME"

    # 清理临时目录
    rm -rf "$TEMP_DMG_DIR"
}

# 公证（可选）
notarize_app() {
    log_info "提交公证..."

    # 检查是否配置了 App Store Connect 凭据
    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_SPECIFIC_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
        log_warn "未配置 Apple 凭据，跳过公证"
        log_warn "设置以下环境变量以启用公证:"
        log_warn "  APPLE_ID - Apple ID 邮箱"
        log_warn "  APPLE_APP_SPECIFIC_PASSWORD - App 专用密码"
        log_warn "  APPLE_TEAM_ID - Team ID"
        return
    fi

    # 存储凭据（如果尚未存储）
    xcrun notarytool store-credentials "bvi-notarize" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        2>/dev/null || true

    # 提交公证
    xcrun notarytool submit "$OUTPUT_DIR/$DMG_NAME" \
        --keychain-profile "bvi-notarize" \
        --wait

    # Staple 公证票据
    xcrun stapler staple "$OUTPUT_DIR/$DMG_NAME"

    log_info "公证完成"
}

# 主流程
main() {
    local NOTARIZE=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --notarize)
                NOTARIZE=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [--notarize]"
                echo ""
                echo "选项:"
                echo "  --notarize    提交 Apple 公证（需要配置凭据）"
                echo "  --help, -h    显示帮助信息"
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                exit 1
                ;;
        esac
    done

    check_dependencies
    build_app
    create_app_bundle
    sign_app
    create_dmg

    if [ "$NOTARIZE" = true ]; then
        notarize_app
    fi

    log_info "打包完成！"
    log_info "输出文件: $OUTPUT_DIR/$DMG_NAME"

    # 显示文件大小
    if [ -f "$OUTPUT_DIR/$DMG_NAME" ]; then
        SIZE=$(du -h "$OUTPUT_DIR/$DMG_NAME" | cut -f1)
        log_info "文件大小: $SIZE"
    fi
}

main "$@"
