/// Coze AI 智能体服务
/// 处理与豆包智能体的API交互，包括SSE流式响应解析
///
/// 功能：
/// - NVC分析（观察-感受-需要-请求）
/// - SSE流式响应处理
/// - 灵活的JSON解析

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/insight_report.dart';
import '../constants/app_constants.dart';

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

    // 添加日志拦截器（仅开发环境）
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false, // SSE响应太大，不记录
      logPrint: (obj) => print('CozeAI: $obj'),
    ));
  }

  /// NVC 洞察分析
  ///
  /// 将用户的转写文本发送给智能体，获取NVC分析结果
  ///
  /// [transcription] 转写文本
  /// 返回 NVCAnalysis 对象
  Future<NVCAnalysis> analyzeNVC(String transcription) async {
    // 检查配置（只需要 Token 和 Project ID）
    if (EnvConfig.cozeApiToken.isEmpty || EnvConfig.cozeProjectId.isEmpty) {
      throw CozeAPIException(
        'Coze AI 配置未完成，请在 .env 文件中配置 COZE_API_TOKEN 和 COZE_PROJECT_ID',
        code: 'CONFIG_ERROR',
      );
    }

    print('🤖 CozeAI: 开始NVC分析，文本长度: ${transcription.length}');

    try {
      // 构建提示词
      final promptText = _buildNVCPrompt(transcription);

      // 调用 Coze API
      final responseText = await _callCozeAPI(promptText);

      print('✅ CozeAI: 收到AI响应，长度: ${responseText.length}');
      print('📝 CozeAI: AI原始响应内容:\n$responseText');

      // 解析响应
      final nvcAnalysis = _parseNVCResponse(responseText, transcription);

      print('✅ CozeAI: NVC分析完成');
      print('📊 CozeAI: 解析结果 - 观察: ${nvcAnalysis.observation}');
      print('📊 CozeAI: 解析结果 - 感受: ${nvcAnalysis.feelings}');
      print('📊 CozeAI: 解析结果 - 需要: ${nvcAnalysis.needs}');
      print('📊 CozeAI: 解析结果 - 请求: ${nvcAnalysis.request}');
      print('📊 CozeAI: 解析结果 - AI洞察: ${nvcAnalysis.insight}');
      return nvcAnalysis;
    } on DioException catch (e) {
      throw CozeAPIException.fromDioError(e);
    } catch (e) {
      throw CozeAPIException(
        'NVC分析失败: $e',
        code: 'PARSE_ERROR',
        originalError: e,
      );
    }
  }

  /// 构建 NVC 分析提示词
  String _buildNVCPrompt(String transcription) {
    return '''你是一位专业的非暴力沟通（NVC）教练。请对以下文本进行深入的NVC分析。

文本内容：
「$transcription」

请从以下4个维度进行详细分析：

1. **观察（Observation）**：
   - 客观描述文本中提到的具体事实
   - 去除评判、解读和假设
   - 用"我看到/听到..."的方式描述

2. **感受（Feelings）**：
   - 识别说话者可能的情绪感受
   - 至少提供2-3个具体的感受词汇
   - 可以是：焦虑、困惑、兴奋、失望、感激等
   - 即使文本很短，也要根据语境推测可能的感受

3. **需要（Needs）**：
   - 分析这些感受背后未被满足的核心需求
   - 至少提供2-3个需求
   - 可以是：理解、尊重、安全感、自主性、连接等
   - 说明为什么有这个需求

4. **请求（Requests）**：
   - 提供2-3个具体、可行的沟通建议
   - 建议应该是正向的、具体的行动
   - 例如："尝试在双方情绪平稳时，以'我'开头表达感受"

**重要**：
- 不要返回空数组，必须提供具体的分析内容
- 即使文本很短，也要根据语境进行合理推测
- 返回的JSON必须包含实际内容，不能只是重复文本

请以JSON格式返回分析结果，**必须严格遵循以下格式**：
{
  "observation": "客观观察的内容（具体描述事实）",
  "feelings": ["感受1", "感受2", "感受3"],
  "needs": ["需要1", "需要2", "需要3"],
  "requests": ["具体建议1", "具体建议2", "具体建议3"],
  "insight": "总结性的AI洞察（可选）"
}

示例（针对"你总是不听我说话"）：
{
  "observation": "说话者提到对方'不听我说话'的情况发生频率很高",
  "feelings": ["沮丧", "被忽视", "孤独"],
  "needs": ["被倾听", "被理解", "连接"],
  "requests": [
    "请在我说话时保持眼神接触",
    "听完我的话后，用自己的语言重复一遍你的理解",
    "如果现在不方便，请告诉我什么时候可以好好聊"
  ],
  "insight": "说话者渴望被看见和理解，建议双方约定专门的沟通时间"
}

现在请分析上面的文本「$transcription」，返回详细的JSON分析结果：''';
  }

  /// 调用 Coze API（SSE流式响应）
  Future<String> _callCozeAPI(String promptText) async {
    // 生成唯一的session_id
    final sessionId = _uuid.v4().replaceAll('-', '');

    print('🔄 CozeAI: 发送请求，session_id: $sessionId');

    final response = await _dio.post(
      '/stream_run',
      data: {
        'content': {
          'query': {
            'prompt': [
              {
                'type': 'text',
                'content': {'text': promptText},
              },
            ],
          },
        },
        'type': 'query',
        'session_id': sessionId,
        'project_id': EnvConfig.cozeProjectId,
      },
      // 关键：使用流式响应
      options: Options(responseType: ResponseType.stream),
    );

    if (response.statusCode == 200 && response.data is ResponseBody) {
      // 解析SSE流
      final streamText = await utf8.decoder.bind(response.data.stream).join();
      print('📥 CozeAI: 收到流式响应，长度: ${streamText.length}');

      final answer = _extractAnswerFromSSE(streamText);
      return answer.isNotEmpty ? answer : streamText;
    }

    throw CozeAPIException(
      'API响应无效: HTTP ${response.statusCode}',
      code: 'INVALID_RESPONSE',
    );
  }

  /// 从 SSE 流中提取答案
  String _extractAnswerFromSSE(String streamText) {
    final buffer = StringBuffer();
    final lines = streamText.split(RegExp(r'\r?\n'));

    int eventCount = 0;
    int answerEventCount = 0;

    for (final line in lines) {
      final trimmed = line.trim();

      // 只处理 "data:" 开头的行
      if (!trimmed.startsWith('data:')) continue;

      final data = trimmed.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;

      try {
        final jsonData = jsonDecode(data) as Map<String, dynamic>;
        eventCount++;

        final eventType = jsonData['type'] ?? 'unknown';

        // 只有answer类型的事件才包含实际内容
        if (eventType == 'answer') {
          answerEventCount++;
          final answer = _tryExtractAnswer(jsonData);

          if (answer != null && answer.isNotEmpty) {
            buffer.write(answer);
          }
        }
      } catch (e) {
        // 静默处理解析错误
        continue;
      }
    }

    final result = buffer.toString();
    print('✅ CozeAI: SSE解析完成: $eventCount个事件, ${answerEventCount}个answer事件, 提取${result.length}字符');

    return result;
  }

  /// 从事件JSON中提取答案
  String? _tryExtractAnswer(Map<String, dynamic> jsonData) {
    // 检查 type == 'answer' 时的 content.answer
    if (jsonData['type'] == 'answer') {
      final content = jsonData['content'];
      if (content is Map) {
        final answer = content['answer'];
        if (answer is String && answer.isNotEmpty) {
          return answer;
        }
      }
    }

    // 尝试其他可能的字段
    final content = jsonData['content'];
    if (content is Map) {
      return content['answer'] ?? content['text'] ?? content['message'];
    }

    return null;
  }

  /// 解析 NVC 响应（灵活解析多种JSON格式）
  NVCAnalysis _parseNVCResponse(String responseText, String originalText) {
    try {
      // 尝试从响应中提取JSON（可能被markdown代码块包裹）
      final jsonText = _extractJsonFromText(responseText);
      print('🔍 CozeAI: 提取的JSON文本:\n$jsonText');

      final jsonData = jsonDecode(jsonText) as Map<String, dynamic>;
      print('🔍 CozeAI: 解析的JSON对象: $jsonData');

      return _parseFlexibleNVCJson(jsonData, originalText);
    } catch (e) {
      print('⚠️ CozeAI: JSON解析失败: $e');
      print('⚠️ CozeAI: 原始响应文本: $responseText');

      // 检查响应是否包含错误信息
      if (responseText.contains('503003') ||
          responseText.contains('数据库连接') ||
          responseText.contains('error') ||
          responseText.contains('Error') ||
          responseText.length < 50) {
        // 抛出异常，触发错误对话框
        throw CozeAPIException(
          'AI服务暂时不可用，请稍后重试',
          code: 'SERVICE_ERROR',
          originalError: e,
        );
      }

      // 如果不是明显的错误，但无法解析JSON，也抛出异常
      throw CozeAPIException(
        'AI响应格式异常，无法解析',
        code: 'PARSE_ERROR',
        originalError: e,
      );
    }
  }

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

    // 原样返回
    return text.trim();
  }

  /// 生成周洞察报告
  ///
  /// [records] 本周记录列表
  /// [weekRange] 周范围（如：2026-01-27 ~ 2026-02-02）
  /// 返回 InsightReport 对象
  Future<InsightReport> generateInsight(
    List<InsightRequestRecord> records,
    String weekRange,
  ) async {
    // 检查配置
    if (EnvConfig.cozeApiToken.isEmpty || EnvConfig.cozeInsightProjectId.isEmpty) {
      throw CozeAPIException(
        '洞察智能体配置未完成，请在 .env 文件中配置 COZE_API_TOKEN 和 COZE_INSIGHT_PROJECT_ID',
        code: 'CONFIG_ERROR',
      );
    }

    if (records.isEmpty) {
      throw CozeAPIException(
        '没有足够的记录生成洞察',
        code: 'NO_RECORDS',
      );
    }

    print('🔮 CozeAI: 开始生成洞察，记录数: ${records.length}');

    try {
      // 构建请求内容（将记录转换为 JSON 数组）
      final recordsJson = records.map((r) => {
        'record_time': r.recordTime,
        'content': r.content,
      }).toList();
      final promptText = jsonEncode(recordsJson);

      // 调用洞察 API
      final responseText = await _callInsightAPI(promptText);

      print('✅ CozeAI: 收到洞察响应，长度: ${responseText.length}');
      print('📝 CozeAI: 洞察原始响应:\n$responseText');

      // 解析响应
      final report = _parseInsightResponse(responseText, weekRange, records.length);

      print('✅ CozeAI: 洞察生成完成');
      return report;
    } on DioException catch (e) {
      throw CozeAPIException.fromDioError(e);
    } catch (e) {
      if (e is CozeAPIException) rethrow;
      throw CozeAPIException(
        '洞察生成失败: $e',
        code: 'INSIGHT_ERROR',
        originalError: e,
      );
    }
  }

  /// 调用洞察 API（SSE流式响应）
  Future<String> _callInsightAPI(String promptText) async {
    // 创建单独的 Dio 实例用于洞察 API
    final insightDio = Dio();
    insightDio.options.baseUrl = EnvConfig.cozeInsightBaseUrl;
    insightDio.options.connectTimeout = AppConstants.cozeApiTimeout;
    insightDio.options.receiveTimeout = const Duration(seconds: 120); // 洞察可能需要更长时间
    insightDio.options.headers = {
      'Authorization': 'Bearer ${EnvConfig.cozeApiToken}',
      'Content-Type': 'application/json',
    };

    // 生成唯一的 session_id
    final sessionId = _uuid.v4().replaceAll('-', '');

    print('🔄 CozeAI: 发送洞察请求，session_id: $sessionId');
    print('🔄 CozeAI: 使用 project_id: ${EnvConfig.cozeInsightProjectId}');

    final response = await insightDio.post(
      '/stream_run',
      data: {
        'content': {
          'query': {
            'prompt': [
              {
                'type': 'text',
                'content': {'text': promptText},
              },
            ],
          },
        },
        'type': 'query',
        'session_id': sessionId,
        'project_id': int.parse(EnvConfig.cozeInsightProjectId),
      },
      options: Options(responseType: ResponseType.stream),
    );

    if (response.statusCode == 200 && response.data is ResponseBody) {
      final streamText = await utf8.decoder.bind(response.data.stream).join();
      print('📥 CozeAI: 收到洞察流式响应，长度: ${streamText.length}');

      final answer = _extractAnswerFromSSE(streamText);
      return answer.isNotEmpty ? answer : streamText;
    }

    throw CozeAPIException(
      '洞察API响应无效: HTTP ${response.statusCode}',
      code: 'INVALID_RESPONSE',
    );
  }

  /// 解析洞察响应
  InsightReport _parseInsightResponse(String responseText, String weekRange, int recordCount) {
    try {
      // 尝试从响应中提取 JSON
      final jsonText = _extractJsonFromText(responseText);
      print('🔍 CozeAI: 提取的洞察JSON:\n$jsonText');

      final jsonData = jsonDecode(jsonText) as Map<String, dynamic>;

      return _parseInsightJson(jsonData, weekRange, recordCount);
    } catch (e) {
      print('⚠️ CozeAI: 洞察JSON解析失败: $e');
      print('⚠️ CozeAI: 原始响应: $responseText');

      // 检查是否是服务错误
      if (responseText.contains('error') ||
          responseText.contains('Error') ||
          responseText.length < 100) {
        throw CozeAPIException(
          'AI服务暂时不可用，请稍后重试',
          code: 'SERVICE_ERROR',
          originalError: e,
        );
      }

      throw CozeAPIException(
        '洞察响应格式异常，无法解析',
        code: 'PARSE_ERROR',
        originalError: e,
      );
    }
  }

  /// 解析洞察 JSON
  InsightReport _parseInsightJson(
    Map<String, dynamic> json,
    String weekRange,
    int recordCount,
  ) {
    // 解析情绪概览
    final emotionOverviewData = json['emotion_overview'] as Map<String, dynamic>?;
    final emotionOverview = EmotionOverview(
      summary: emotionOverviewData?['summary']?.toString() ?? '本周记录不足，无法生成完整的情绪分析。',
    );

    // 解析高频情境
    final highFrequencyList = json['high_frequency_emotions'] as List<dynamic>? ?? [];
    final highFrequencyEmotions = highFrequencyList.map((item) {
      final map = item as Map<String, dynamic>;
      return HighFrequencyEmotion(
        content: map['content']?.toString() ?? '',
        time: map['time']?.toString() ?? '',
      );
    }).toList();

    // 解析模式假设
    final patternData = json['pattern_hypothesis'] as Map<String, dynamic>?;
    final highlightTagsList = patternData?['highlight_tags'] as List<dynamic>? ?? [];
    final highlightTags = highlightTagsList.map((item) {
      final map = item as Map<String, dynamic>;
      return HighlightTag(
        key: map['key']?.toString() ?? '',
        value: map['value']?.toString() ?? '',
      );
    }).toList();

    final patternHypothesis = PatternHypothesis(
      text: patternData?['text']?.toString() ?? '暂无足够数据分析情绪模式',
      highlightTags: highlightTags,
    );

    // 解析行动建议
    final actionList = json['action_suggestions'] as List<dynamic>? ?? [];
    final actionSuggestions = actionList.map((item) {
      final map = item as Map<String, dynamic>;
      return ActionSuggestion(
        title: map['title']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
      );
    }).toList();

    return InsightReport(
      id: _uuid.v4(),
      reportType: json['report_type']?.toString() ?? '每周洞察报告',
      emotionOverview: emotionOverview,
      highFrequencyEmotions: highFrequencyEmotions,
      patternHypothesis: patternHypothesis,
      actionSuggestions: actionSuggestions,
      weekRange: weekRange,
      createdAt: DateTime.now(),
      recordCount: recordCount,
    );
  }

  /// 灵活解析NVC JSON（支持多种字段名和格式）
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

    // 感受：支持List和String格式，转换为Feeling对象
    List<Feeling> feelings = [];
    final feelingsField = json['feelings'] ?? json['感受'] ?? json['情绪'];
    if (feelingsField is List) {
      feelings = feelingsField.map((e) {
        if (e is Map) {
          // 如果是对象格式，尝试解析
          try {
            return Feeling.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            // 解析失败，创建简化版
            return Feeling(
              feeling: e['feeling']?.toString() ?? e.toString(),
              intensity: IntensityLevel.medium,
            );
          }
        } else {
          // 如果是字符串，创建默认强度的Feeling
          return Feeling(
            feeling: e.toString(),
            intensity: IntensityLevel.medium,
          );
        }
      }).toList();
    } else if (feelingsField is String) {
      feelings = [
        Feeling(
          feeling: feelingsField,
          intensity: IntensityLevel.medium,
        )
      ];
    }

    // 需要：支持List和String格式，转换为Need对象
    List<Need> needs = [];
    final needsField = json['needs'] ?? json['需要'] ?? json['需求'];
    if (needsField is List) {
      needs = needsField.map((e) {
        if (e is Map) {
          // 如果是对象格式，尝试解析
          try {
            return Need.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            // 解析失败，创建简化版
            return Need(
              need: e['need']?.toString() ?? e.toString(),
              reason: e['reason']?.toString() ?? '',
            );
          }
        } else {
          // 如果是字符串，创建默认Need
          return Need(
            need: e.toString(),
            reason: '',
          );
        }
      }).toList();
    } else if (needsField is String) {
      needs = [
        Need(
          need: needsField,
          reason: '',
        )
      ];
    }

    // 请求：支持多种字段名和格式
    String? request;
    final requestsField = json['requests'] ?? json['请求'] ?? json['建议'] ?? json['request'];
    if (requestsField is List && requestsField.isNotEmpty) {
      // 如果是列表，格式化为带序号的列表
      request = requestsField
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .join('\n');
    } else if (requestsField is String && requestsField.isNotEmpty) {
      request = requestsField;
    }

    // AI洞察
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
}

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
