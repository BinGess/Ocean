#!/bin/bash

# NVC 洞察功能测试指南
# 运行此脚本前，请确保已配置 .env 文件

echo "======================================"
echo "   NVC 洞察功能测试指南"
echo "======================================"
echo ""

# 1. 检查 .env 文件
echo "步骤 1: 检查配置文件"
echo "------------------------------------"
if [ -f .env ]; then
    echo "✅ .env 文件存在"

    # 检查必需的配置项（不显示实际值）
    if grep -q "COZE_API_TOKEN=" .env && [ ! -z "$(grep COZE_API_TOKEN= .env | cut -d'=' -f2)" ]; then
        echo "✅ COZE_API_TOKEN 已配置"
    else
        echo "❌ COZE_API_TOKEN 未配置或为空"
    fi

    if grep -q "COZE_PROJECT_ID=" .env && [ ! -z "$(grep COZE_PROJECT_ID= .env | cut -d'=' -f2)" ]; then
        echo "✅ COZE_PROJECT_ID 已配置"
    else
        echo "❌ COZE_PROJECT_ID 未配置或为空"
    fi

    if grep -q "COZE_BOT_ID=" .env && [ ! -z "$(grep COZE_BOT_ID= .env | cut -d'=' -f2)" ]; then
        echo "✅ COZE_BOT_ID 已配置"
    else
        echo "❌ COZE_BOT_ID 未配置或为空"
    fi

    if grep -q "COZE_BASE_URL=" .env && [ ! -z "$(grep COZE_BASE_URL= .env | cut -d'=' -f2)" ]; then
        echo "✅ COZE_BASE_URL 已配置"
    else
        echo "❌ COZE_BASE_URL 未配置或为空"
    fi
else
    echo "❌ .env 文件不存在，请先创建"
    exit 1
fi

echo ""
echo "步骤 2: 清理并获取依赖"
echo "------------------------------------"
echo "运行: flutter clean"
flutter clean

echo "运行: flutter pub get"
flutter pub get

echo ""
echo "步骤 3: 运行应用"
echo "------------------------------------"
echo "请手动运行以下命令："
echo "  flutter run"
echo ""
echo "或者在 VS Code/Android Studio 中点击运行按钮"
echo ""

echo ""
echo "步骤 4: 测试 NVC 洞察功能"
echo "------------------------------------"
echo "1. 打开应用后，点击录音按钮"
echo "2. 说一段话（例如：\"我今天很开心，因为完成了一个重要的项目\"）"
echo "3. 停止录音，等待转写完成"
echo "4. 在弹出的选项中，点击 'NVC 洞察'（深紫色图标）"
echo "5. 观察是否显示加载指示器"
echo "6. 等待 5-15 秒"
echo ""

echo "步骤 5: 查看调试日志"
echo "------------------------------------"
echo "在终端中查找以下日志输出："
echo ""
echo "✅ 成功的标志："
echo "  - '🤖 CozeAI: 开始NVC分析，文本长度: ...'"
echo "  - '📥 CozeAI: 收到流式响应，长度: ...'"
echo "  - '✅ CozeAI: SSE解析完成: X个事件, Y个answer事件'"
echo "  - '✅ CozeAI: 收到AI响应，长度: ...'"
echo "  - 'RecordBloc: NVC insight completed'"
echo ""
echo "❌ 错误的标志："
echo "  - 'Coze AI 配置未完成'"
echo "  - '网络超时，请检查网络连接'"
echo "  - 'API Token 无效或已过期'"
echo "  - 'NVC洞察失败: ...'"
echo ""

echo "步骤 6: 预期结果"
echo "------------------------------------"
echo "如果成功，你应该看到："
echo "  - 观察 (蓝色区域): 客观事实描述"
echo "  - 感受 (粉色区域): 情绪列表"
echo "  - 需要 (紫色区域): 需求列表"
echo "  - 请求 (绿色区域): 具体建议"
echo "  - AI洞察 (黄色区域): 深度分析"
echo ""

echo "======================================"
echo "   祝测试顺利！"
echo "======================================"
echo ""
echo "如果遇到问题，请："
echo "1. 复制完整的错误日志"
echo "2. 检查 .env 文件配置是否正确"
echo "3. 确认网络连接正常"
echo "4. 检查 Coze 平台的 API 状态"
