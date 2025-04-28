#!/bin/bash

set -e

SOLUTION_NAME="FileRenamer.sln"
PROJECT_DIR="FileRenamer.Avalonia"
PROJECT_FILE="$PROJECT_DIR/FileRenamer.Avalonia.csproj"
OUTPUT_BASE_DIR="publish"
CONFIG="Release"

declare -a RIDS=(
    "win-x64"
    "win-x86"
    "osx-x64"
    "osx-arm64"
)

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT="$SCRIPT_DIR"

echo "开始为 $SOLUTION_NAME 进行跨平台构建..."
echo "项目根目录: $PROJECT_ROOT"
echo "输出目录: $PROJECT_ROOT/$OUTPUT_BASE_DIR"

if [ -d "$PROJECT_ROOT/$OUTPUT_BASE_DIR" ]; then
    echo "正在清理之前的构建输出: $PROJECT_ROOT/$OUTPUT_BASE_DIR..."
    rm -rf "$PROJECT_ROOT/$OUTPUT_BASE_DIR"
fi
mkdir -p "$PROJECT_ROOT/$OUTPUT_BASE_DIR"

echo "构建项目: $PROJECT_ROOT/$PROJECT_FILE"

for RID in "${RIDS[@]}"
do
    echo "--------------------------------------------------"
    echo "正在为运行时标识符 (RID): $RID 构建"
    echo "--------------------------------------------------"

    if [[ "$RID" == "win-x64" ]]; then
        OUTPUT_NAME="FileRenamer-Windows-x64"
    elif [[ "$RID" == "win-x86" ]]; then
        OUTPUT_NAME="FileRenamer-Windows-x86"
    elif [[ "$RID" == "osx-x64" ]]; then
        OUTPUT_NAME="FileRenamer-macOS-x64"
    elif [[ "$RID" == "osx-arm64" ]]; then
        OUTPUT_NAME="FileRenamer-macOS-arm64"
    fi

    RID_OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_BASE_DIR/$OUTPUT_NAME"
    mkdir -p "$RID_OUTPUT_DIR"

    if [[ "$RID" == "win-x64" || "$RID" == "win-x86" ]]; then
        PUBLISH_SINGLE_FILE="true"
        echo "为 Windows ($RID) 启用 PublishSingleFile=true"
    else
        PUBLISH_SINGLE_FILE="false"
        echo "为 macOS 平台 ($RID) 禁用 PublishSingleFile=false"
    fi

    dotnet publish "$PROJECT_ROOT/$PROJECT_FILE" \
        --configuration "$CONFIG" \
        --runtime "$RID" \
        --output "$RID_OUTPUT_DIR" \
        -p:PublishSingleFile=$PUBLISH_SINGLE_FILE \
        -p:SelfContained=true

    echo "构建成功: $RID."
    echo "输出位于: $RID_OUTPUT_DIR"

    if [[ "$RID" == "osx-x64" || "$RID" == "osx-arm64" ]]; then
        echo "为 macOS ($RID) 创建 .app 包..."
        APP_BUNDLE_DIR="$RID_OUTPUT_DIR/FileRenamer.app"
        CONTENTS_DIR="$APP_BUNDLE_DIR/Contents"
        MACOS_DIR="$CONTENTS_DIR/MacOS"
        RESOURCES_DIR="$CONTENTS_DIR/Resources"

        mkdir -p "$MACOS_DIR"
        mkdir -p "$RESOURCES_DIR"

        mv "$RID_OUTPUT_DIR/"* "$MACOS_DIR/" 2>/dev/null || true

        cp "$PROJECT_ROOT/$PROJECT_DIR/assets/icon.icns" "$RESOURCES_DIR/" 2>/dev/null || true

        cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FileRenamer</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.filerenamer</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>FileRenamer</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

        echo ".app 包创建成功: $APP_BUNDLE_DIR"
    fi

    echo "正在为 $OUTPUT_NAME 压缩输出..."
    (cd "$PROJECT_ROOT/$OUTPUT_BASE_DIR" && zip -qr "$OUTPUT_NAME.zip" "$OUTPUT_NAME")
done

echo "=================================================="
echo "所有跨平台构建成功完成！"
echo "输出产物位于: $PROJECT_ROOT/$OUTPUT_BASE_DIR"
echo "每个子目录对应一个特定的运行时标识符 (RID)，并已生成对应的 zip 存档。"
echo "=================================================="

exit 0
