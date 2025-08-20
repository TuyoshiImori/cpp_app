#!/bin/bash
# コード修正後に一発でビルド→インストール→起動するスクリプト

DEVICE_ID="00008130-00092DA400C1401C"
BUNDLE_ID="com.iiyotu.CSAApp"
APP_PATH="/Users/iimoritsuyoshi/projects/CSAApp/build/Debug-iphoneos/CSAApp.app"

set -e

# 1. ビルド（署名付き）
echo "🔨 ビルド中..."
xcodebuild -project CSAApp.xcodeproj -target CSAApp -configuration Debug -sdk iphoneos build

# 2. インストール
echo "📱 デバイスにインストール中..."
# devicectl の --device オプションはサポートされていないため、device id を位置引数で渡す
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

# 3. 起動
echo "🎯 アプリを起動中..."
# 同様に device id を位置引数で渡す
# Launch the app via the "process launch" subcommand which accepts --device
# and bundle identifier as its argument. Use --activate to bring app to foreground.
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" --activate

echo "✅ 一括ビルド・インストール・起動完了！"
