#!/bin/bash
# bash ./launch_app.shを実行してアプリを起動
# CSAApp 高速起動スクリプト
# デバイスに直接インストールして起動

DEVICE_ID="00008130-00092DA400C1401C"
BUNDLE_ID="com.iiyotu.CSAApp"

echo "🚀 CSAApp 高速起動中..."

# アプリをデバイスにインストール
echo "📱 デバイスにインストール中..."
xcrun devicectl device install app --device $DEVICE_ID /Users/iimoritsuyoshi/Library/Developer/Xcode/DerivedData/CSAApp-aedxfuyqghkhdiexdbdmdjlltome/Build/Products/Debug-iphoneos/CSAApp.app

# アプリを起動
echo "🎯 アプリを起動中..."
xcrun devicectl device launch app --device $DEVICE_ID $BUNDLE_ID

echo "✅ CSAApp 起動完了！"
