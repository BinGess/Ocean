#!/bin/bash

# MindFlow Flutter 项目快速设置脚本
# 使用方法: chmod +x setup.sh && ./setup.sh

set -e

echo "🚀 MindFlow Flutter 项目设置"
echo "================================"

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装或不在 PATH 中"
    echo "📖 请参考 SETUP.md 安装 Flutter SDK"
    exit 1
fi

echo "✅ Flutter 已安装"
flutter --version

# 运行 flutter doctor
echo ""
echo "🔍 检查 Flutter 环境..."
flutter doctor

# 询问用户是否继续
echo ""
read -p "是否继续设置项目？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# 第一步：生成平台代码
echo ""
echo "📱 步骤 1/5: 生成平台代码..."
if [ -d "android" ] && [ -d "ios" ]; then
    echo "⚠️  平台代码已存在，跳过..."
else
    flutter create . --org com.mindflow.app --project-name mindflow
    echo "✅ 平台代码生成完成"
fi

# 第二步：安装依赖
echo ""
echo "📦 步骤 2/5: 安装 Flutter 依赖..."
flutter pub get
echo "✅ 依赖安装完成"

# 第三步：生成代码
echo ""
echo "🔨 步骤 3/5: 运行代码生成..."
flutter pub run build_runner build --delete-conflicting-outputs
echo "✅ 代码生成完成"

# 第四步：配置环境变量
echo ""
echo "🔐 步骤 4/5: 配置环境变量..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "✅ 已创建 .env 文件"
    echo "⚠️  请编辑 .env 文件，填入您的豆包 API 密钥"
else
    echo "⚠️  .env 文件已存在，跳过..."
fi

# 第五步：检查设备
echo ""
echo "📱 步骤 5/5: 检查可用设备..."
flutter devices

echo ""
echo "🎉 设置完成！"
echo ""
echo "下一步："
echo "1. 编辑 .env 文件，填入豆包 API 密钥"
echo "2. 运行 'flutter run' 启动应用"
echo "3. 参考 SETUP.md 了解更多配置选项"
echo ""
echo "常用命令："
echo "  flutter run              # 运行应用（Debug 模式）"
echo "  flutter run --release    # 运行应用（Release 模式）"
echo "  flutter devices          # 查看可用设备"
echo "  flutter clean            # 清理构建缓存"
echo "  flutter analyze          # 代码分析"
echo ""
