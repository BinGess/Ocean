# 豆包 API 配置和调试指南

## 📝 概述

MindFlow 使用豆包（Doubao）提供的两个 API 服务：
1. **ASR API** - 语音识别（WebSocket）
2. **LLM API** - 大语言模型（REST API）

本指南将帮助您获取 API 密钥、配置环境变量，并调试 API 连接。

---

## 🔑 第一步：获取 API 密钥

### 1. 豆包 ASR（语音识别）

访问：https://console.volcengine.com/speech/service

1. **登录火山引擎控制台**
2. **开通语音技术服务**
   - 选择"语音识别" → "实时语音识别"
   - 创建应用并获取密钥

3. **获取以下信息：**
   - `APP_KEY` - 应用标识
   - `ACCESS_KEY` - 访问密钥
   - `RESOURCE_ID` - 资源 ID（通常为 `volc.bigasr.sauc.duration`）

### 2. 豆包 LLM（大语言模型）

访问：https://console.volcengine.com/ark

1. **登录火山引擎方舟控制台**
2. **创建 API Key**
   - 进入"API 管理" → "创建 API Key"
   - 选择模型：`doubao-pro-32k` 或 `doubao-pro-128k`

3. **获取以下信息：**
   - `API_KEY` - API 密钥
   - `MODEL_ID` - 模型 ID

---

## ⚙️ 第二步：配置环境变量

### 1. 创建 `.env` 文件

在项目根目录创建 `.env` 文件（如果还没有）：

```bash
# 从模板复制
cp .env.example .env
```

### 2. 填写 API 密钥

编辑 `.env` 文件，填入您的 API 密钥：

```env
# 豆包 ASR API 配置
DOUBAO_ASR_APP_KEY=your_asr_app_key_here
DOUBAO_ASR_ACCESS_KEY=your_asr_access_key_here
DOUBAO_ASR_RESOURCE_ID=volc.bigasr.sauc.duration

# 豆包 LLM API 配置
DOUBAO_LLM_API_KEY=your_llm_api_key_here
DOUBAO_MODEL_ID=doubao-pro-32k
```

### 3. 验证配置

运行以下命令验证 `.env` 文件格式正确：

```bash
cat .env
```

**注意事项：**
- ⚠️ **不要**将 `.env` 文件提交到 Git（已在 `.gitignore` 中）
- ✅ 密钥应该是长字符串（通常 32-64 字符）
- ✅ 不要在密钥前后加引号

---

## 🧪 第三步：测试 API 连接

### 使用内置调试工具

1. **启动应用**
   ```bash
   flutter run
   ```

2. **打开 API 测试页面**
   - 在首页右上角，点击"齿轮"图标
   - 选择"API 调试"

3. **查看配置状态**
   - 绿色 ✅ = 配置完整
   - 橙色 ⚠️ = 配置不完整

4. **测试 LLM API**
   - 点击"测试 LLM API"按钮
   - 查看日志输出，应该看到：
     ```
     ✅ LLM API 响应成功
     📝 响应内容: {...}
     ```

5. **测试 ASR WebSocket**
   - 点击"测试 ASR WebSocket"按钮
   - 查看日志输出，应该看到：
     ```
     ✅ WebSocket 已连接
     ✅ 音频包已发送
     ```

---

## 🔍 第四步：调试常见问题

### 问题 1: "❌ 环境变量配置不完整"

**原因：** `.env` 文件缺失或格式错误

**解决方案：**
1. 检查 `.env` 文件是否存在于项目根目录
2. 检查文件名是否正确（`.env`，不是 `env.txt`）
3. 检查是否有拼写错误（如 `DOUBAO_LLM_API_KEy`）
4. 重启应用（`flutter run`）

```bash
# 验证文件
ls -la .env

# 检查内容
cat .env
```

### 问题 2: "❌ LLM API 请求失败 - 401 Unauthorized"

**原因：** API Key 无效或过期

**解决方案：**
1. 登录火山引擎控制台验证 API Key 是否有效
2. 检查 API Key 是否复制完整（没有多余的空格或换行）
3. 确认 API Key 有足够的额度（检查余额）
4. 重新生成 API Key 并更新 `.env`

```env
# 确保 API Key 格式正确，不要有空格
DOUBAO_LLM_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 问题 3: "❌ ASR WebSocket 连接失败"

**原因：** WebSocket 参数错误或网络问题

**解决方案：**
1. 检查 `APP_KEY`、`ACCESS_KEY`、`RESOURCE_ID` 是否正确
2. 确认网络连接正常（可以访问火山引擎服务）
3. 检查防火墙是否阻止了 WebSocket 连接
4. 在真机上测试（模拟器可能有网络限制）

```bash
# 测试网络连接
ping openspeech.bytedance.com
```

### 问题 4: "⚠️ 加载 .env 文件失败"

**原因：** `.env` 文件未包含在应用资源中

**解决方案：**
1. 检查 `pubspec.yaml` 是否包含 `.env`：
   ```yaml
   flutter:
     assets:
       - .env
   ```

2. 运行 `flutter clean` 并重新构建：
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 问题 5: "❌ LLM 响应格式错误"

**原因：** 模型返回的 JSON 格式不符合预期

**解决方案：**
1. 检查使用的模型是否支持 JSON 模式
2. 在日志中查看原始响应内容
3. 尝试使用不同的模型（如 `doubao-pro-128k`）
4. 检查提示词是否明确要求 JSON 格式

---

## 📱 第五步：在应用中使用 API

### 基本录音流程

1. **用户长按录音按钮** → 开始录音
2. **释放按钮** → 停止录音
3. **选择处理模式：**
   - 只记录：仅保存转写文本
   - 情绪标记：AI 推荐需要
   - NVC 分析：完整的情绪分析

### API 调用时机

```dart
// 1. 录音结束后，发送音频到 ASR
final transcription = await aiRepository.transcribeAudio(audioData);

// 2. 根据用户选择的模式处理
switch (mode) {
  case ProcessingMode.withMood:
    // 推荐需要
    final needs = await aiRepository.recommendNeeds(moods: selectedMoods);
    break;

  case ProcessingMode.withNVC:
    // NVC 分析
    final nvc = await aiRepository.analyzeWithNVC(transcription);
    break;
}
```

### 查看 API 日志

启用详细日志输出：

```bash
# 运行时启用详细日志
flutter run --verbose
```

在代码中添加日志：

```dart
import 'package:logger/logger.dart';

final logger = Logger();

// 在 API 调用前后添加日志
logger.d('发送 ASR 请求: ${audioData.length} bytes');
logger.i('ASR 响应: $transcription');
logger.e('API 错误: $error');
```

---

## 🎯 最佳实践

### 1. 错误处理

```dart
try {
  final result = await aiRepository.transcribeAudio(audioData);
  // 处理成功结果
} catch (e) {
  // 显示友好的错误提示
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('语音识别失败，请重试')),
  );

  // 记录详细错误到日志
  logger.e('ASR 错误', e);
}
```

### 2. 超时处理

```dart
final result = await aiRepository
    .transcribeAudio(audioData)
    .timeout(Duration(seconds: 30), onTimeout: () {
      throw TimeoutException('语音识别超时');
    });
```

### 3. 重试机制

```dart
Future<String> transcribeWithRetry(Uint8List audioData) async {
  int retries = 3;
  Duration delay = Duration(seconds: 1);

  for (int i = 0; i < retries; i++) {
    try {
      return await aiRepository.transcribeAudio(audioData);
    } catch (e) {
      if (i == retries - 1) rethrow;
      await Future.delayed(delay);
      delay *= 2; // 指数退避
    }
  }

  throw Exception('重试失败');
}
```

### 4. 缓存优化

```dart
// 缓存常用的 LLM 响应（如需要推荐）
final _needsCache = <String, List<String>>{};

Future<List<String>> getCachedNeeds(List<String> moods) async {
  final key = moods.join(',');

  if (_needsCache.containsKey(key)) {
    return _needsCache[key]!;
  }

  final needs = await aiRepository.recommendNeeds(moods: moods);
  _needsCache[key] = needs;

  return needs;
}
```

---

## 📊 监控和调试

### 查看 API 调用统计

在 API 测试页面中可以查看：
- ✅ 成功调用次数
- ❌ 失败调用次数
- ⏱️ 平均响应时间
- 💰 预估费用

### 导出日志

在 API 测试页面中：
1. 点击右上角"复制"图标
2. 日志会复制到剪贴板
3. 粘贴到文本文件保存或分享

### 使用 Flutter DevTools

```bash
# 启动 DevTools
flutter pub global activate devtools
flutter pub global run devtools

# 在浏览器中打开
# 查看网络请求、日志、性能等
```

---

## 🔒 安全建议

1. **不要硬编码 API 密钥**
   - ❌ 不要：`final apiKey = 'sk-xxxxx';`
   - ✅ 应该：从 `.env` 读取

2. **不要提交敏感信息到 Git**
   - 确保 `.env` 在 `.gitignore` 中
   - 使用 `.env.example` 作为模板

3. **定期轮换 API 密钥**
   - 建议每 3-6 个月更新一次
   - 如果密钥泄露，立即更换

4. **限制 API 调用频率**
   - 实现防抖（debounce）机制
   - 避免短时间内大量请求

---

## 📚 参考资料

- [火山引擎语音识别文档](https://www.volcengine.com/docs/6561/79819)
- [火山引擎方舟 LLM 文档](https://www.volcengine.com/docs/82379/1099522)
- [Flutter Dotenv 文档](https://pub.dev/packages/flutter_dotenv)
- [WebSocket 调试工具](https://www.websocket.org/echo.html)

---

## ❓ 常见问题 FAQ

**Q: API 有免费额度吗？**
A: 火山引擎通常提供新用户免费额度，具体请查看控制台。

**Q: 如何计费？**
A: ASR 按识别时长计费，LLM 按 Token 数量计费。查看控制台了解详情。

**Q: 支持离线识别吗？**
A: 当前版本仅支持在线 API，离线功能需要额外集成。

**Q: 可以切换到其他 AI 服务吗？**
A: 可以，通过实现 `AIRepository` 接口即可替换不同的 AI 服务。

**Q: 如何优化识别准确率？**
A: 确保音频质量良好（无噪音）、使用清晰的语音、选择合适的模型。

---

## 🆘 获取帮助

如果遇到问题：
1. 查看应用内日志（API 测试页面）
2. 查看 Flutter 控制台输出（`flutter run --verbose`）
3. 检查本文档的常见问题部分
4. 联系火山引擎技术支持

---

**祝您调试顺利！** 🎉
