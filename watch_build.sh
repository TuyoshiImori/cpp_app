#!/bin/bash

# CSAApp 自動ビルド・ウォッチスクリプト
# ファイル変更を監視して自動的に増分ビルドを実行

echo "🚀 CSAApp 自動ビルド・ウォッチモード開始"
echo "📁 監視対象: CSAApp/View, CSAApp/ViewModel, CSAApp/Model"

# 初回ビルド
echo "🔨 初回ビルド中..."
xcodebuild -workspace CSAApp.xcworkspace -scheme CSAApp -configuration Debug -sdk iphoneos build

# ファイル変更を監視して自動ビルド
fswatch -o CSAApp/View CSAApp/ViewModel CSAApp/Model | while read -r num_changes; do
    echo "📝 ファイル変更を検出！増分ビルド開始..."
    time xcodebuild -workspace CSAApp.xcworkspace -scheme CSAApp -configuration Debug -sdk iphoneos build
    echo "✅ 増分ビルド完了！"
done
