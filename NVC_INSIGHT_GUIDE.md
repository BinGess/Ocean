# NVC 洞察功能使用指南

## 功能概述

NVC 洞察是基于 Coze AI 智能体的深度情绪分析功能，能够自动将用户的语音转写文本进行非暴力沟通(NVC)分析，帮助用户更好地理解自己的情绪和需求。

### 核心特性

- ✅ **SSE 流式响应**：实时接收 AI 分析结果
- ✅ **灵活 JSON 解析**：支持多种字段名（中英文）和嵌套结构
- ✅ **智能降级**：Coze AI → 豆包 LLM → 默认结果
- ✅ **完整 NVC 结构**：观察、感受、需要、请求、AI洞察
- ✅ **精美 UI 展示**：每个维度有专属的颜色主题和图标

---

## 配置指南

### 1. 创建 .env 文件

在项目根目录创建 `.env` 文件（参考 `.env.example`）：

```env
# 豆包 ASR (语音识别) 配置
DOUBAO_ASR_APP_KEY=your_app_key_here
DOUBAO_ASR_ACCESS_KEY=your_access_key_here
DOUBAO_ASR_RESOURCE_ID=volc.seedasr.sauc.duration

# Coze AI (智能体) 配置
COZE_API_TOKEN=your_coze_api_token_here
COZE_BASE_URL=https://ypcqkgr32q.coze.site
COZE_PROJECT_ID=your_project_id_here
COZE_BOT_ID=your_bot_id_here
```

### 2. 获取 Coze AI 凭证

1. 访问 [Coze 平台](https://www.coze.cn)
2. 创建或选择一个智能体
3. 获取以下信息：
   - **API Token**：用于身份验证
   - **Project ID**：项目标识符
   - **Bot ID**：智能体标识符
   - **Base URL**：API 端点地址

### 3. 配置智能体 Prompt

在 Coze 平台配置智能体时，建议使用以下系统提示词：

```
你是一个专业的NVC（非暴力沟通）分析师。用户会提供一段文字，请从以下4个维度进行分析：

1. 观察（Observation）：客观描述发生了什么事情，不带评判
2. 感受（Feelings）：识别当事人的真实情绪感受
3. 需要（Needs）：分析未被满足的核心需求
4. 请求（Requests）：提供具体可行的改进建议

请以JSON格式返回分析结果：
{
  "observation": "客观观察的内容",
  "feelings": ["感受1", "感受2"],
  "needs": ["需要1", "需要2"],
  "requests": ["请求1", "请求2"],
  "insight": "AI的深度洞察和建议"
}
```

---

## 使用流程

### 用户操作流程

1. **录音**
   - 打开应用，点击录音按钮
   - 说出你想记录的内容
   - 再次点击按钮停止录音

2. **选择处理方式**
   - 系统自动进行语音转写
   - 弹出处理选项模态框
   - 可以看到转写文本预览

3. **触发 NVC 洞察**
   - 点击 "NVC 洞察" 选项（深紫色，auto_awesome 图标）
   - 系统开始分析（显示加载指示器）
   - 等待 5-15 秒（取决于文本长度）

4. **查看分析结果**
   - **观察**：蓝色区域，客观事实描述
   - **感受**：粉色区域，识别的情绪
   - **需要**：紫色区域，未满足的需求
   - **请求**：绿色区域，具体建议
   - **AI 洞察**：黄色区域，深度分析（如果有）

5. **保存或取消**
   - 点击 "保存记录" 将分析结果和音频保存
   - 点击 "取消" 返回选项菜单

### 技术流程

```
录音完成
  ↓
语音转写 (DoubaoASRClient)
  ↓
显示选项模态框 (ProcessingChoiceModal)
  ↓
点击"NVC 洞察"
  ↓
触发 RecordNVCInsight 事件
  ↓
RecordBloc 调用 AIRepository.analyzeWithNVC()
  ↓
AIRepository 优先使用 CozeAIService
  ↓
CozeAIService 发送 SSE 请求到 Coze API
  ↓
解析 SSE 流式响应
  ↓
提取并解析 JSON 结果
  ↓
转换为 NVCAnalysis 对象
  ↓
更新 RecordState
  ↓
UI 自动刷新显示结果
```

---

## 代码架构

### 核心文件

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart        # Coze配置
│   ├── network/
│   │   └── coze_ai_service.dart      # Coze AI服务
│   └── di/
│       └── injection.dart             # 依赖注入
├── data/
│   └── repositories/
│       └── ai_repository_impl.dart    # AI仓储实现
├── domain/
│   ├── entities/
│   │   └── nvc_analysis.dart          # NVC实体
│   └── repositories/
│       └── ai_repository.dart         # AI仓储接口
└── presentation/
    ├── bloc/
    │   └── record/
    │       ├── record_bloc.dart       # Record业务逻辑
    │       ├── record_event.dart      # RecordNVCInsight事件
    │       └── record_state.dart      # nvcAnalysis字段
    ├── screens/
    │   └── home/
    │       └── home_screen.dart       # NVC结果UI
    └── widgets/
        └── processing_choice_modal.dart # NVC洞察按钮
```

### 关键类

#### CozeAIService

```dart
class CozeAIService {
  /// NVC 洞察分析
  Future<NVCAnalysis> analyzeNVC(String transcription);

  /// 调用 Coze API（SSE流式响应）
  Future<String> _callCozeAPI(String promptText);

  /// 从 SSE 流中提取答案
  String _extractAnswerFromSSE(String streamText);

  /// 灵活解析NVC JSON（支持多种字段名和格式）
  NVCAnalysis _parseFlexibleNVCJson(Map<String, dynamic> json, String originalText);
}
```

#### AIRepositoryImpl

```dart
class AIRepositoryImpl implements AIRepository {
  final CozeAIService? cozeAIService;

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) async {
    // 优先使用 Coze AI
    if (cozeAIService != null && EnvConfig.isCozeConfigured) {
      try {
        return await cozeAIService!.analyzeNVC(transcription);
      } catch (e) {
        // 降级到豆包 LLM
      }
    }

    // 降级处理...
  }
}
```

#### RecordBloc

```dart
class RecordBloc extends Bloc<RecordEvent, RecordState> {
  /// NVC 洞察分析
  Future<void> _onNVCInsight(
    RecordNVCInsight event,
    Emitter<RecordState> emit,
  ) async {
    emit(state.copyWith(status: RecordStatus.nvcAnalyzing));

    try {
      final nvcAnalysis = await aiRepository.analyzeWithNVC(event.transcription);
      emit(state.copyWith(
        status: RecordStatus.success,
        nvcAnalysis: nvcAnalysis,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'NVC洞察失败: $e',
      ));
    }
  }
}
```

---

## 错误处理

### 常见错误

#### 1. 配置错误

**错误信息**: `Coze AI 配置未完成`

**解决方案**:
- 检查 `.env` 文件是否存在
- 确认所有 Coze 相关配置项都已填写
- 运行应用前重新加载环境变量

#### 2. 网络超时

**错误信息**: `网络超时，请检查网络连接`

**解决方案**:
- 检查网络连接
- 确认 `COZE_BASE_URL` 可访问
- 调整超时配置（`app_constants.dart` 中的 `cozeApiTimeout`）

#### 3. API Token 无效

**错误信息**: `API Token 无效或已过期`

**解决方案**:
- 登录 Coze 平台检查 Token 状态
- 重新生成 Token
- 更新 `.env` 文件中的 `COZE_API_TOKEN`

#### 4. JSON 解析失败

**错误信息**: `NVC洞察失败: FormatException`

**解决方案**:
- 检查智能体的 Prompt 配置
- 确保返回格式为有效的 JSON
- 查看日志中的原始响应内容
- 灵活解析会自动降级，通常不会完全失败

### 降级策略

系统具有三层降级机制：

1. **Coze AI**（优先）
   - 智能体深度分析
   - 最准确和详细的结果

2. **豆包 LLM**（降级1）
   - 基于豆包大模型的分析
   - 质量稍次于专门训练的智能体

3. **默认结果**（降级2）
   - 将转写文本作为观察
   - 感受、需要、请求字段为空
   - 保证应用不会崩溃

---

## 性能优化

### 1. 缓存策略

当前版本暂未实现缓存，但可以添加：

```dart
class CacheService {
  static const String _cachePrefix = 'nvc_insight_cache_';

  Future<NVCAnalysis?> get(String transcriptionHash) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_cachePrefix + transcriptionHash);
    // ...
  }

  Future<bool> set(String transcriptionHash, NVCAnalysis value) async {
    // 缓存24小时
    final expiryTime = DateTime.now().add(Duration(hours: 24));
    // ...
  }
}
```

### 2. 请求优化

- 超时时间：连接30秒，接收60秒
- 重试机制：最多3次（目前未实现，可添加）
- 流式响应：边接收边处理

### 3. UI 优化

- 使用 `BlocBuilder` 精确重建
- 加载状态与结果展示分离
- 模态框延迟关闭以避免闪烁

---

## 调试指南

### 启用详细日志

所有关键步骤都有 `print` 日志输出：

```dart
// CozeAIService
print('🤖 CozeAI: 开始NVC分析，文本长度: ${transcription.length}');
print('✅ CozeAI: SSE解析完成: $eventCount个事件');

// AIRepositoryImpl
print('🤖 AIRepository: 使用 Coze AI 进行 NVC 洞察');
print('⚠️ AIRepository: Coze AI 分析失败，降级到豆包LLM: $e');

// RecordBloc
print('RecordBloc: Starting NVC insight for text: ...');
print('RecordBloc: NVC insight completed');
```

### 调试检查清单

1. ✅ 环境变量加载成功
   - 查看启动日志：`✅ 环境变量已加载`

2. ✅ WebSocket 连接成功
   - 查看：`✅ ASRClient: WebSocket 握手成功!`
   - 查看：`ASRClient: Response JSON: ...`

3. ✅ Coze API 请求发送
   - 查看：`🤖 CozeAI: 开始NVC分析`
   - 查看：`🔄 CozeAI: 发送请求，session_id: ...`

4. ✅ SSE 流接收
   - 查看：`📥 CozeAI: 收到流式响应，长度: ...`
   - 查看：`✅ CozeAI: SSE解析完成: X个事件, Y个answer事件`

5. ✅ JSON 解析成功
   - 查看：`✅ CozeAI: 收到AI响应，长度: ...`

6. ✅ Bloc 状态更新
   - 查看：`RecordBloc: NVC insight completed`
   - 查看：`RecordBloc: State updated with NVC analysis`

---

## 最佳实践

### 1. Prompt 设计

**推荐格式**:
- 明确要求 JSON 格式
- 列出所有字段名称
- 提供示例输出
- 强调 NVC 四要素

**避免**:
- 模糊的指令
- 过于复杂的嵌套结构
- 不稳定的字段名

### 2. 错误提示

**用户友好**:
```dart
// ❌ 错误
Text('DioException: SocketException: Connection refused');

// ✅ 正确
Text('网络连接失败，请检查网络设置');
```

### 3. 日志管理

**开发环境**:
- 详细日志（JSON内容、Hex数据等）
- 完整的调试信息

**生产环境**:
- 精简日志（只记录长度、状态）
- 不输出敏感信息（API Token、用户数据）

---

## 扩展功能

### 未来可能的增强

1. **批量分析**
   - 分析多条记录的情绪趋势
   - 生成周期性洞察报告

2. **个性化建议**
   - 基于用户历史数据
   - 学习用户的沟通模式

3. **多语言支持**
   - 中文、英文、日文等
   - 跨语言 NVC 分析

4. **导出功能**
   - 导出 NVC 分析报告（PDF、Markdown）
   - 分享到社交平台

5. **语音交互**
   - 语音提问获取更多洞察
   - 实时对话式 NVC 指导

---

## 参考资料

- [Coze 平台文档](https://www.coze.cn/docs)
- [NVC 非暴力沟通理论](https://www.cnvc.org/)
- [Flutter BLoC 文档](https://bloclibrary.dev/)
- [Dio HTTP 客户端](https://pub.dev/packages/dio)

---

**最后更新**: 2026-01-23
**版本**: v1.0.0
**作者**: MindFlow Team
