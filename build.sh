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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT="$SCRIPT_DIR"

echo "开始为 $SOLUTION_NAME 进行跨平台构建 (Windows 和 macOS)..."
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
    echo "正在为运行时标识符 (RID): $RID 构建"

    RID_OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_BASE_DIR/$RID"
    mkdir -p "$RID_OUTPUT_DIR"

    if [[ "$RID" == "win-x64" || "$RID" == "win-x86" ]]; then
        PUBLISH_SINGLE_FILE="true"
        echo "为 Windows 平台 ($RID) 启用 PublishSingleFile=true"
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
        APP_BUNDLE_DIR="$RID_OUTPUT_DIR/FileRenamer.Avalonia.app"
        CONTENTS_DIR="$APP_BUNDLE_DIR/Contents"
        MACOS_DIR="$CONTENTS_DIR/MacOS"
        RESOURCES_DIR="$CONTENTS_DIR/Resources"

        mkdir -p "$MACOS_DIR"
        mkdir -p "$RESOURCES_DIR"

        mv "$RID_OUTPUT_DIR/"* "$MACOS_DIR/" 2>/dev/null || true

        if [ -f "$PROJECT_ROOT/$PROJECT_DIR/assets/icon.icns" ]; then
             cp "$PROJECT_ROOT/$PROJECT_DIR/assets/icon.icns" "$RESOURCES_DIR/"
        else
             echo "警告: 未找到图标文件 $PROJECT_ROOT/$PROJECT_DIR/assets/icon.icns"
        fi

        cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FileRenamer.Avalonia</string>
    <key>CFBundleDisplayName</key>
    <string>File Renamer</string> <key>CFBundleIdentifier</key>
    <string>com.yourcompany.filerenamer</string> <key>CFBundleVersion</key>
    <string>1.0.0</string> <key>CFBundleShortVersionString</key>
    <string>1.0</string> <key>CFBundleExecutable</key>
    <string>FileRenamer.Avalonia</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string> <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>10.14</string> </dict>
</plist>
EOF
        chmod +x "$MACOS_DIR/FileRenamer.Avalonia"

        echo ".app 包创建成功: $APP_BUNDLE_DIR"
    fi

    ZIP_FILENAME="FileRenamer-$RID.zip"
    echo "正在为 $RID 压缩输出到 $ZIP_FILENAME ..."
    (cd "$PROJECT_ROOT/$OUTPUT_BASE_DIR" && zip -qr "$ZIP_FILENAME" "$RID")
    echo "压缩完成: $PROJECT_ROOT/$OUTPUT_BASE_DIR/$ZIP_FILENAME"

done

echo "Windows 和 macOS 平台的构建成功完成！"
echo "输出产物位于: $PROJECT_ROOT/$OUTPUT_BASE_DIR"
echo "每个子目录对应一个特定的运行时标识符 (RID)。"
echo "已为每个平台生成对应的 zip 存档。"

exit 0