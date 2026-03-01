# Coze AI 智能体集成技能文档

> 本文档整理了与 Coze AI 智能体交互的完整代码模式，包括 SSE 流式响应处理、JSON 解析、错误处理和重试机制。

## 目录

1. [架构概览](#架构概览)
2. [环境配置](#环境配置)
3. [核心服务类](#核心服务类)
4. [数据模型](#数据模型)
5. [SSE 流式响应处理](#sse-流式响应处理)
6. [JSON 解析策略](#json-解析策略)
7. [错误处理与重试](#错误处理与重试)
8. [完整代码模板](#完整代码模板)
9. [最佳实践](#最佳实践)

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        应用层 (Presentation)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  BLoC/Cubit │  │   Widgets   │  │     State Management    │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
└─────────┼────────────────┼──────────────────────┼───────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                        领域层 (Domain)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Use Cases  │  │  Entities   │  │  Repository Interface   │  │
│  └──────┬──────┘  └─────────────┘  └────────────┬────────────┘  │
└─────────┼───────────────────────────────────────┼───────────────┘
          │                                       │
          ▼                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                        数据层 (Data)                             │
│  ┌───────────────────────┐  ┌───────────────────────────────┐   │
│  │  Repository Impl      │  │       Data Sources            │   │
│  │  (降级策略/多源聚合)    │  │  ┌─────────────────────────┐  │   │
│  └───────────┬───────────┘  │  │    CozeAIService        │  │   │
│              │              │  │  (SSE 流式响应处理)       │  │   │
│              │              │  └─────────────────────────┘  │   │
│              │              │  ┌─────────────────────────┐  │   │
│              │              │  │   DoubaoDataSource      │  │   │
│              │              │  │  (备用 LLM 服务)         │  │   │
│              │              │  └─────────────────────────┘  │   │
│              │              └───────────────────────────────┘   │
└──────────────┼──────────────────────────────────────────────────┘
               │
               ▼
       ┌───────────────┐
       │  Coze AI API  │
       │  (SSE Stream) │
       └───────────────┘
```

---

## 环境配置

### .env 文件配置

```env
# Coze AI 智能体配置（NVC 分析）
COZE_API_TOKEN=your_coze_api_token
COZE_BASE_URL=https://your-bot-id.coze.site
COZE_PROJECT_ID=your_project_id

# Coze 洞察智能体配置（独立配置）
COZE_INSIGHT_API_TOKEN=your_insight_api_token
COZE_INSIGHT_BASE_URL=https://your-insight-bot.coze.site
COZE_INSIGHT_PROJECT_ID=your_insight_project_id
```

### EnvConfig 类

```dart
/// 环境变量配置（从 .env 文件读取）
class EnvConfig {
  // Coze AI (智能体) API
  static String get cozeApiToken =>
      dotenv.get('COZE_API_TOKEN', fallback: '').trim();

  static String get cozeBaseUrl =>
      dotenv.get('COZE_BASE_URL', fallback: 'https://xxx.coze.site').trim();

  static String get cozeProjectId =>
      dotenv.get('COZE_PROJECT_ID', fallback: '').trim();

  // Coze 洞察智能体配置（独立的 Token 和 URL）
  static String get cozeInsightApiToken =>
      dotenv.get('COZE_INSIGHT_API_TOKEN', fallback: '').trim();

  static String get cozeInsightBaseUrl =>
      dotenv.get('COZE_INSIGHT_BASE_URL', fallback: 'https://xxx.coze.site').trim();

  static String get cozeInsightProjectId =>
      dotenv.get('COZE_INSIGHT_PROJECT_ID', fallback: '').trim();

  /// 验证 Coze AI 配置是否完整
  static bool get isCozeConfigured {
    return cozeApiToken.isNotEmpty && cozeProjectId.isNotEmpty;
  }

  /// 验证洞察智能体配置是否完整
  static bool get isInsightConfigured {
    return cozeInsightApiToken.isNotEmpty && cozeInsightProjectId.isNotEmpty;
  }
}
```

### 常量配置

```dart
class AppConstants {
  // API 超时配置
  static const Duration cozeApiTimeout = Duration(seconds: 30);
  static const Duration cozeReceiveTimeout = Duration(seconds: 60);

  // Coze AI 配置
  static const int cozeMaxRetries = 3;
  static const int cozeRetryDelaySeconds = 2;
}
```

---

## 核心服务类

### CozeAIService 完整实现

```dart
/// Coze AI 智能体服务
/// 处理与豆包智能体的API交互，包括SSE流式响应解析
class CozeAIService {
  final Dio _dio;
  final Uuid _uuid = const Uuid();

  CozeAIService({Dio? dio}) : _dio = dio ?? Dio() {
    _configureDio();
  }

  /// 配置 Dio 客户端
  void _configureDio() {
    _dio.options.baseUrl = EnvConfig.cozeBaseUrl;
    _dio.options.connectTimeout = AppConstants.cozeApiTimeout;
    _dio.options.receiveTimeout = AppConstants.cozeReceiveTimeout;
    _dio.options.headers = {
      'Authorization': 'Bearer ${EnvConfig.cozeApiToken}',
      'Content-Type': 'application/json',
    };
  }

  /// 调用智能体 API（通用方法）
  /// [userInput] 用户输入文本
  /// [projectId] 项目ID
  /// [apiToken] API Token（可选，默认使用配置）
  /// [baseUrl] 基础URL（可选，默认使用配置）
  Future<String> callAgent({
    required String userInput,
    required int projectId,
    String? apiToken,
    String? baseUrl,
  }) async {
    final dio = Dio();
    dio.options.baseUrl = baseUrl ?? EnvConfig.cozeBaseUrl;
    dio.options.connectTimeout = AppConstants.cozeApiTimeout;
    dio.options.receiveTimeout = const Duration(seconds: 120);
    dio.options.headers = {
      'Authorization': 'Bearer ${apiToken ?? EnvConfig.cozeApiToken}',
      'Content-Type': 'application/json',
    };

    final sessionId = _uuid.v4().replaceAll('-', '');

    final response = await dio.post(
      '/stream_run',
      data: {
        'content': {
          'query': {
            'prompt': [
              {
                'type': 'text',
                'content': {'text': userInput},
              },
            ],
          },
        },
        'type': 'query',
        'session_id': sessionId,
        'project_id': projectId,
      },
      options: Options(responseType: ResponseType.stream),
    );

    if (response.statusCode == 200 && response.data is ResponseBody) {
      final streamText = await utf8.decoder.bind(response.data.stream).join();
      return _extractAnswerFromSSE(streamText);
    }

    throw CozeAPIException(
      'API响应无效: HTTP ${response.statusCode}',
      code: 'INVALID_RESPONSE',
    );
  }
}
```

---

## 数据模型

### 基础实体（使用 Freezed）

```dart
/// 感受强度等级
enum IntensityLevel {
  @JsonValue(1) veryLow,
  @JsonValue(2) low,
  @JsonValue(3) medium,
  @JsonValue(4) high,
  @JsonValue(5) veryHigh,
}

/// 感受项
@freezed
class Feeling with _$Feeling {
  const factory Feeling({
    required String feeling,
    required IntensityLevel intensity,
  }) = _Feeling;

  factory Feeling.fromJson(Map<String, dynamic> json) =>
      _$FeelingFromJson(json);
}

/// 需要项
@freezed
class Need with _$Need {
  const factory Need({
    required String need,
    required String reason,
  }) = _Need;

  factory Need.fromJson(Map<String, dynamic> json) => _$NeedFromJson(json);
}

/// NVC 分析结果
@freezed
class NVCAnalysis with _$NVCAnalysis {
  const factory NVCAnalysis({
    required String observation,      // 观察（客观事实描述）
    required List<Feeling> feelings,  // 感受列表
    required List<Need> needs,        // 需要列表
    String? request,                  // 请求（可选）
    String? insight,                  // AI 洞察（可选）
    required DateTime analyzedAt,     // 分析时间戳
  }) = _NVCAnalysis;

  factory NVCAnalysis.fromJson(Map<String, dynamic> json) =>
      _$NVCAnalysisFromJson(json);
}
```

### 洞察报告实体

```dart
/// 情绪概览
@freezed
class EmotionOverview with _$EmotionOverview {
  const factory EmotionOverview({
    required String summary,  // 总结内容（约300字以内）
  }) = _EmotionOverview;

  factory EmotionOverview.fromJson(Map<String, dynamic> json) =>
      _$EmotionOverviewFromJson(json);
}

/// 高频情境
@freezed
class HighFrequencyEmotion with _$HighFrequencyEmotion {
  const factory HighFrequencyEmotion({
    required String content,  // 记录内容
    required String time,     // 时间（如：周四 14:15）
  }) = _HighFrequencyEmotion;

  factory HighFrequencyEmotion.fromJson(Map<String, dynamic> json) =>
      _$HighFrequencyEmotionFromJson(json);
}

/// 高亮标签
@freezed
class HighlightTag with _$HighlightTag {
  const factory HighlightTag({
    required String key,    // 标签键（如：trigger, value）
    required String value,  // 标签值
  }) = _HighlightTag;

  factory HighlightTag.fromJson(Map<String, dynamic> json) =>
      _$HighlightTagFromJson(json);
}

/// 模式假设（潜在需求挖掘）
@freezed
class PatternHypothesis with _$PatternHypothesis {
  const factory PatternHypothesis({
    required String text,
    @JsonKey(name: 'highlight_tags') required List<HighlightTag> highlightTags,
  }) = _PatternHypothesis;

  factory PatternHypothesis.fromJson(Map<String, dynamic> json) =>
      _$PatternHypothesisFromJson(json);
}

/// 行动建议
@freezed
class ActionSuggestion with _$ActionSuggestion {
  const factory ActionSuggestion({
    required String title,
    required String content,
  }) = _ActionSuggestion;

  factory ActionSuggestion.fromJson(Map<String, dynamic> json) =>
      _$ActionSuggestionFromJson(json);
}

/// 洞察报告
@freezed
class InsightReport with _$InsightReport {
  const factory InsightReport({
    required String id,
    @JsonKey(name: 'report_type') required String reportType,
    @JsonKey(name: 'emotion_overview') required EmotionOverview emotionOverview,
    @JsonKey(name: 'high_frequency_emotions') required List<HighFrequencyEmotion> highFrequencyEmotions,
    @JsonKey(name: 'pattern_hypothesis') required PatternHypothesis patternHypothesis,
    @JsonKey(name: 'action_suggestions') required List<ActionSuggestion> actionSuggestions,
    @JsonKey(name: 'week_range') required String weekRange,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'record_count') int? recordCount,
  }) = _InsightReport;

  factory InsightReport.fromJson(Map<String, dynamic> json) =>
      _$InsightReportFromJson(json);
}

/// 洞察请求记录
@freezed
class InsightRequestRecord with _$InsightRequestRecord {
  const factory InsightRequestRecord({
    @JsonKey(name: 'record_time') required String recordTime,
    required String content,
  }) = _InsightRequestRecord;

  factory InsightRequestRecord.fromJson(Map<String, dynamic> json) =>
      _$InsightRequestRecordFromJson(json);
}
```

---

## SSE 流式响应处理

### SSE 解析核心逻辑

```dart
/// 从 SSE 流中提取答案
/// 如果检测到服务端错误，会抛出 CozeAPIException
String _extractAnswerFromSSE(String streamText) {
  final buffer = StringBuffer();
  final lines = streamText.split(RegExp(r'\r?\n'));

  for (final line in lines) {
    final trimmed = line.trim();

    // 只处理 "data:" 开头的行
    if (!trimmed.startsWith('data:')) continue;

    final data = trimmed.substring(5).trim();
    if (data.isEmpty || data == '[DONE]') continue;

    try {
      final jsonData = jsonDecode(data) as Map<String, dynamic>;
      final eventType = jsonData['type'] ?? 'unknown';

      // 检查 message_end 中是否有错误码
      if (eventType == 'message_end') {
        final content = jsonData['content'] as Map<String, dynamic>?;
        final messageEnd = content?['message_end'] as Map<String, dynamic>?;
        if (messageEnd != null) {
          final errorCode = messageEnd['code']?.toString();
          final errorMessage = messageEnd['message']?.toString() ?? '';

          if (errorCode != null && errorCode != '0' && errorCode.isNotEmpty) {
            throw CozeAPIException(
              '服务暂时不可用，请稍后重试',
              code: 'SERVICE_ERROR_$errorCode',
              originalError: errorMessage,
            );
          }
        }
      }

      // 只有 answer 类型的事件才包含实际内容
      if (eventType == 'answer') {
        final answer = _tryExtractAnswer(jsonData);
        if (answer != null && answer.isNotEmpty) {
          buffer.write(answer);
        }
      }
    } catch (e) {
      if (e is CozeAPIException) rethrow;
      continue;  // 其他解析错误静默处理
    }
  }

  return buffer.toString();
}

/// 从事件 JSON 中提取答案
String? _tryExtractAnswer(Map<String, dynamic> jsonData) {
  if (jsonData['type'] == 'answer') {
    final content = jsonData['content'];
    if (content is Map) {
      final answer = content['answer'];
      if (answer is String && answer.isNotEmpty) {
        return answer;
      }
    }
  }

  final content = jsonData['content'];
  if (content is Map) {
    return content['answer'] ?? content['text'] ?? content['message'];
  }

  return null;
}
```

### SSE 事件类型说明

| 事件类型 | 说明 | 处理方式 |
|---------|------|---------|
| `answer` | 包含 AI 回复内容 | 累加到结果 buffer |
| `message_end` | 消息结束标记 | 检查错误码 |
| `thinking` | 思考过程（可选） | 可忽略或显示 |
| `tool_call` | 工具调用（可选） | 根据需要处理 |

---

## JSON 解析策略

### 从文本中提取 JSON

```dart
/// 从文本中提取JSON（处理markdown代码块）
String _extractJsonFromText(String text) {
  // 尝试提取 ```json ... ``` 或 ``` ... ``` 代码块
  final codeBlockPattern = RegExp(
    r'```(?:json)?\s*\n?([\s\S]*?)\n?```',
    multiLine: true,
  );

  final match = codeBlockPattern.firstMatch(text);
  if (match != null) {
    return match.group(1)!.trim();
  }

  // 尝试查找 { ... } JSON对象
  final jsonObjectPattern = RegExp(
    r'\{[\s\S]*\}',
    multiLine: true,
  );

  final jsonMatch = jsonObjectPattern.firstMatch(text);
  if (jsonMatch != null) {
    return jsonMatch.group(0)!;
  }

  return text.trim();
}
```

### 灵活字段名解析

```dart
/// 灵活解析 NVC JSON（支持多种字段名和格式）
NVCAnalysis _parseFlexibleNVCJson(
  Map<String, dynamic> json,
  String originalText,
) {
  // 观察：支持多种字段名
  String observation = '';
  if (json['observation'] != null) {
    observation = json['observation'].toString();
  } else if (json['观察'] != null) {
    observation = json['观察'].toString();
  } else if (json['事实'] != null) {
    observation = json['事实'].toString();
  }

  // 如果没有观察，使用原始文本
  if (observation.isEmpty) {
    observation = originalText;
  }

  // 感受：支持 List 和 String 格式
  List<Feeling> feelings = [];
  final feelingsField = json['feelings'] ?? json['感受'] ?? json['情绪'];
  if (feelingsField is List) {
    feelings = feelingsField.map((e) {
      if (e is Map) {
        try {
          return Feeling.fromJson(e as Map<String, dynamic>);
        } catch (_) {
          return Feeling(
            feeling: e['feeling']?.toString() ?? e.toString(),
            intensity: IntensityLevel.medium,
          );
        }
      } else {
        return Feeling(
          feeling: e.toString(),
          intensity: IntensityLevel.medium,
        );
      }
    }).toList();
  } else if (feelingsField is String) {
    feelings = [
      Feeling(feeling: feelingsField, intensity: IntensityLevel.medium)
    ];
  }

  // 需要：支持 List 和 String 格式
  List<Need> needs = [];
  final needsField = json['needs'] ?? json['需要'] ?? json['需求'];
  if (needsField is List) {
    needs = needsField.map((e) {
      if (e is Map) {
        try {
          return Need.fromJson(e as Map<String, dynamic>);
        } catch (_) {
          return Need(
            need: e['need']?.toString() ?? e.toString(),
            reason: e['reason']?.toString() ?? '',
          );
        }
      } else {
        return Need(need: e.toString(), reason: '');
      }
    }).toList();
  } else if (needsField is String) {
    needs = [Need(need: needsField, reason: '')];
  }

  // 请求：支持多种字段名和格式
  String? request;
  final requestsField =
      json['requests'] ?? json['请求'] ?? json['建议'] ?? json['request'];
  if (requestsField is List && requestsField.isNotEmpty) {
    request = requestsField
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
  } else if (requestsField is String && requestsField.isNotEmpty) {
    request = requestsField;
  }

  // AI 洞察
  String? insight = json['insight']?.toString() ?? json['洞察']?.toString();

  return NVCAnalysis(
    observation: observation,
    feelings: feelings,
    needs: needs,
    request: request,
    insight: insight,
    analyzedAt: DateTime.now(),
  );
}
```

### JSON 格式修复

```dart
/// 修复洞察 JSON 中的常见格式问题
String _repairInsightJson(String jsonText) {
  // 修复 {"key": "value": "实际值"} -> {"key": "need", "value": "实际值"}
  final pattern1 = RegExp(r'\{"key":\s*"value":\s*"([^"]+)"\}');
  jsonText = jsonText.replaceAllMapped(pattern1, (match) {
    final value = match.group(1);
    return '{"key": "need", "value": "$value"}';
  });

  // 修复不完整的 JSON 末尾
  if (!jsonText.trimRight().endsWith('}')) {
    final lastBrace = jsonText.lastIndexOf('}');
    if (lastBrace > 0) {
      jsonText = jsonText.substring(0, lastBrace + 1);
    }
  }

  return jsonText;
}
```

---

## 错误处理与重试

### 自定义异常类

```dart
/// Coze API 异常
class CozeAPIException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  CozeAPIException(
    this.message, {
    this.code,
    this.originalError,
  });

  factory CozeAPIException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return CozeAPIException(
          '网络超时，请检查网络连接',
          code: 'TIMEOUT',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return CozeAPIException(
            'API Token 无效或已过期',
            code: 'UNAUTHORIZED',
          );
        } else if (statusCode == 429) {
          return CozeAPIException(
            'API 调用频率过高，请稍后再试',
            code: 'RATE_LIMIT',
          );
        }
        return CozeAPIException(
          'API 响应错误：$statusCode',
          code: 'BAD_RESPONSE',
        );

      default:
        return CozeAPIException(
          '未知错误：${error.message}',
          code: 'UNKNOWN',
        );
    }
  }

  @override
  String toString() => 'CozeAPIException($code): $message';
}
```

### 重试机制实现

```dart
/// 带重试的分析方法
Future<NVCAnalysis> analyzeNVC(String transcription, {int maxRetries = 2}) async {
  // 检查配置
  if (EnvConfig.cozeApiToken.isEmpty || EnvConfig.cozeProjectId.isEmpty) {
    throw CozeAPIException(
      'Coze AI 配置未完成',
      code: 'CONFIG_ERROR',
    );
  }

  final userInput = transcription.trim();
  if (userInput.isEmpty) {
    throw CozeAPIException('输入内容为空', code: 'EMPTY_INPUT');
  }

  CozeAPIException? lastError;

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      if (attempt > 0) {
        // 指数退避延迟
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }

      final responseText = await _callCozeAPI(userInput);
      return _parseNVCResponse(responseText, transcription);

    } on CozeAPIException catch (e) {
      lastError = e;
      // 对于服务错误（5xx），尝试重试
      if (e.code?.startsWith('SERVICE_ERROR') == true && attempt < maxRetries) {
        continue;
      }
      rethrow;

    } on DioException catch (e) {
      lastError = CozeAPIException.fromDioError(e);
      // 对于网络超时，尝试重试
      if ((e.type == DioExceptionType.connectionTimeout ||
           e.type == DioExceptionType.receiveTimeout) &&
          attempt < maxRetries) {
        continue;
      }
      throw lastError;

    } catch (e) {
      throw CozeAPIException(
        '分析失败: $e',
        code: 'PARSE_ERROR',
        originalError: e,
      );
    }
  }

  throw lastError ?? CozeAPIException('分析失败，请稍后重试', code: 'UNKNOWN_ERROR');
}
```

---

## 完整代码模板

### 1. 新建智能体服务的模板

```dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// 你的智能体服务
class YourAgentService {
  final Dio _dio;
  final Uuid _uuid = const Uuid();

  YourAgentService({Dio? dio}) : _dio = dio ?? Dio() {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = 'YOUR_BASE_URL';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.headers = {
      'Authorization': 'Bearer YOUR_API_TOKEN',
      'Content-Type': 'application/json',
    };
  }

  /// 调用智能体
  Future<YourResultType> analyze(String input) async {
    final sessionId = _uuid.v4().replaceAll('-', '');

    final response = await _dio.post(
      '/stream_run',
      data: {
        'content': {
          'query': {
            'prompt': [
              {'type': 'text', 'content': {'text': input}},
            ],
          },
        },
        'type': 'query',
        'session_id': sessionId,
        'project_id': YOUR_PROJECT_ID,
      },
      options: Options(responseType: ResponseType.stream),
    );

    if (response.statusCode == 200 && response.data is ResponseBody) {
      final streamText = await utf8.decoder.bind(response.data.stream).join();
      final answer = _extractAnswerFromSSE(streamText);
      return _parseResponse(answer);
    }

    throw Exception('API响应无效');
  }

  String _extractAnswerFromSSE(String streamText) {
    // 复用上面的 SSE 解析逻辑
  }

  YourResultType _parseResponse(String responseText) {
    // 实现你的解析逻辑
  }
}
```

### 2. Repository 降级策略模板

```dart
class AIRepositoryImpl implements AIRepository {
  final PrimaryService primaryService;
  final FallbackService? fallbackService;

  AIRepositoryImpl({
    required this.primaryService,
    this.fallbackService,
  });

  @override
  Future<ResultType> analyze(String input) async {
    Exception? lastError;

    // 优先使用主服务
    if (primaryService != null && EnvConfig.isPrimaryConfigured) {
      try {
        return await primaryService.analyze(input);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // 降级到备用服务
      }
    }

    // 降级：使用备用服务
    if (fallbackService != null) {
      try {
        final result = await fallbackService!.analyze(input);
        if (result != null) return result;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    // 所有方法都失败了
    throw lastError ?? Exception('分析失败：所有服务均不可用');
  }
}
```

---

## 最佳实践

### 1. 配置管理

- 使用 `.env` 文件存储敏感配置
- 提供 `.env.example` 作为模板
- 使用 `flutter_dotenv` 读取环境变量
- 实现 `isConfigured` 检查方法

### 2. 错误处理

- 自定义异常类携带错误码
- 区分可重试错误和不可重试错误
- 使用指数退避重试策略
- 提供用户友好的错误消息

### 3. JSON 解析

- 支持多语言字段名（中英文）
- 处理 markdown 代码块包裹
- 容错处理格式异常
- 提供默认值防止空指针

### 4. SSE 处理

- 正确处理 `data:` 前缀
- 累积多个 `answer` 事件
- 检查 `message_end` 错误码
- 处理 `[DONE]` 结束标记

### 5. 服务降级

- 实现多数据源降级策略
- 主服务失败后自动切换
- 记录降级日志便于排查
- 提供手动选择服务的能力

### 6. 授权管理

- 使用安全存储保存授权状态
- 提供授权/撤销方法
- 使用 Stream 通知状态变化
- 内存缓存减少存储读取

---

## 依赖项

```yaml
dependencies:
  dio: ^5.0.0
  uuid: ^4.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  flutter_dotenv: ^5.1.0
  flutter_secure_storage: ^9.0.0

dev_dependencies:
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  build_runner: ^2.4.0
```

---

## 文件结构

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # 常量和环境配置
│   ├── network/
│   │   └── coze_ai_service.dart    # 智能体服务
│   └── services/
│       └── ai_auth_service.dart    # 授权服务
├── data/
│   ├── datasources/
│   │   └── remote/
│   │       └── your_datasource.dart
│   └── repositories/
│       └── ai_repository_impl.dart # 仓库实现
├── domain/
│   ├── entities/
│   │   ├── nvc_analysis.dart       # NVC 分析实体
│   │   └── insight_report.dart     # 洞察报告实体
│   └── repositories/
│       └── ai_repository.dart      # 仓库接口
└── presentation/
    └── bloc/
        └── your_bloc.dart          # BLoC 状态管理
```

---

## 更新日志

| 版本 | 日期 | 更新内容 |
|-----|------|---------|
| 1.0 | 2026-02-27 | 初始版本，整理自 MindFlow/瞬记 项目 |
