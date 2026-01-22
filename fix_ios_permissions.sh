#!/bin/bash

set -e

echo "🔧 MindFlow iOS 权限配置修复脚本"
echo "=================================="
echo ""

# 检查 iOS 目录是否存在
if [ ! -d "ios" ]; then
    echo "❌ 错误：ios/ 目录不存在"
    echo "请先运行 'flutter create .' 生成平台代码"
    exit 1
fi

# 检查 Info.plist 是否存在
if [ ! -f "ios/Runner/Info.plist" ]; then
    echo "❌ 错误：ios/Runner/Info.plist 不存在"
    echo "请先运行 'flutter create .' 生成平台代码"
    exit 1
fi

# 备份原始文件
echo "📋 备份 Info.plist..."
cp ios/Runner/Info.plist ios/Runner/Info.plist.backup
echo "✅ 已备份到 ios/Runner/Info.plist.backup"
echo ""

# 检查是否已经有权限配置
if grep -q "NSMicrophoneUsageDescription" ios/Runner/Info.plist; then
    echo "⚠️  检测到 Info.plist 中已存在 NSMicrophoneUsageDescription"
    echo "正在更新权限描述..."
    /usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription 'MindFlow 需要访问麦克风来录制您的语音笔记'" ios/Runner/Info.plist
else
    echo "➕ 添加麦克风权限描述..."
    /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'MindFlow 需要访问麦克风来录制您的语音笔记'" ios/Runner/Info.plist
fi

# 添加语音识别权限
if grep -q "NSSpeechRecognitionUsageDescription" ios/Runner/Info.plist; then
    /usr/libexec/PlistBuddy -c "Set :NSSpeechRecognitionUsageDescription 'MindFlow 需要使用语音识别功能将录音转换为文字'" ios/Runner/Info.plist
else
    echo "➕ 添加语音识别权限描述..."
    /usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string 'MindFlow 需要使用语音识别功能将录音转换为文字'" ios/Runner/Info.plist
fi

# 添加后台音频权限
if /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" ios/Runner/Info.plist >/dev/null 2>&1; then
    echo "⚠️  UIBackgroundModes 已存在，跳过..."
else
    echo "➕ 添加后台音频权限..."
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" ios/Runner/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string audio" ios/Runner/Info.plist 2>/dev/null || true
fi

echo "✅ 权限配置已添加"
echo ""

# 清理构建缓存
echo "🧹 清理构建缓存..."
flutter clean
echo "✅ 清理完成"
echo ""

# 重新安装 CocoaPods
echo "📦 重新安装 CocoaPods 依赖..."
cd ios
rm -rf Pods/ Podfile.lock .symlinks/
pod install
cd ..
echo "✅ CocoaPods 依赖已重新安装"
echo ""

# 重新获取 Flutter 依赖
echo "📥 重新获取 Flutter 依赖..."
flutter pub get
echo "✅ Flutter 依赖已更新"
echo ""

echo "=================================="
echo "✅ 修复完成！"
echo ""
echo "现在可以运行应用了："
echo "  flutter run -d 7D86FBC8-B6D5-4FB2-9817-F1353DA12A6F"
echo ""
echo "如果还有问题，请在 Xcode 中打开项目查看详细日志："
echo "  open ios/Runner.xcworkspace"
echo ""
