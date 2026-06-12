/// Coze AI 智能体服务
/// 处理与豆包智能体的API交互，包括SSE流式响应解析
///
/// 功能：
/// - NVC分析（观察-感受-需要-请求）
/// - SSE流式响应处理
/// - 灵活的JSON解析
library;

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/insight_report.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/entities/deep_analysis_result.dart';
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
  /// 内置自动重试机制，对于临时性服务错误会自动重试
  ///
  /// [transcription] 转写文本
  /// [maxRetries] 最大重试次数（默认2次）
  /// 返回 NVCAnalysis 对象
  Future<NVCAnalysis> analyzeNVC(String transcription,
      {int maxRetries = 2}) async {
    // 检查配置（只需要 Token 和 Project ID）
    if (EnvConfig.cozeApiToken.isEmpty || EnvConfig.cozeProjectId.isEmpty) {
      throw CozeAPIException(
        'Coze AI 配置未完成，请在 .env 文件中配置 COZE_API_TOKEN 和 COZE_PROJECT_ID',
        code: 'CONFIG_ERROR',
      );
    }

    final userInput = transcription.trim();
    if (userInput.isEmpty) {
      throw CozeAPIException(
        '输入内容为空，无法进行NVC分析',
        code: 'EMPTY_INPUT',
      );
    }

    print('🤖 CozeAI: 开始NVC分析，文本长度: ${userInput.length}');

    CozeAPIException? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          print('🔄 CozeAI: 第 $attempt 次重试...');
          // 短暂延迟后重试
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        // 调用 Coze API
        final responseText = await _callCozeAPI(userInput);

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
      } on CozeAPIException catch (e) {
        lastError = e;
        // 对于服务错误（5xx错误码），尝试重试
        if (e.code?.startsWith('SERVICE_ERROR') == true &&
            attempt < maxRetries) {
          print('⚠️ CozeAI: 服务暂时不可用，准备重试 (${attempt + 1}/$maxRetries)');
          continue;
        }
        // 其他错误或已用完重试次数，直接抛出
        rethrow;
      } on DioException catch (e) {
        lastError = CozeAPIException.fromDioError(e);
        // 对于网络超时，尝试重试
        if ((e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout) &&
            attempt < maxRetries) {
          print('⚠️ CozeAI: 网络超时，准备重试 (${attempt + 1}/$maxRetries)');
          continue;
        }
        throw lastError;
      } catch (e) {
        throw CozeAPIException(
          'NVC分析失败: $e',
          code: 'PARSE_ERROR',
          originalError: e,
        );
      }
    }

    // 如果所有重试都失败了，抛出最后一个错误
    throw lastError ?? CozeAPIException('分析失败，请稍后重试', code: 'UNKNOWN_ERROR');
  }

  /// 调用 Coze API（SSE流式响应）
  /// [userInput] 必须是用户原始输入文本，不额外拼接系统提示词
  Future<String> _callCozeAPI(String userInput) async {
    // 生成唯一的session_id
    final sessionId = _uuid.v4().replaceAll('-', '');
    final projectIdStr = EnvConfig.cozeProjectId;
    final projectId = int.tryParse(projectIdStr);

    if (projectId == null || projectId <= 0) {
      throw CozeAPIException(
        'NVC智能体 Project ID 配置无效: $projectIdStr',
        code: 'CONFIG_ERROR',
      );
    }

    print('🔄 CozeAI: 发送请求，session_id: $sessionId');

    final response = await _dio.post(
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
  /// 如果检测到服务端错误，会抛出 CozeAPIException
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

        // 检查 message_end 中是否有错误码
        if (eventType == 'message_end') {
          final content = jsonData['content'] as Map<String, dynamic>?;
          final messageEnd = content?['message_end'] as Map<String, dynamic>?;
          if (messageEnd != null) {
            final errorCode = messageEnd['code']?.toString();
            final errorMessage = messageEnd['message']?.toString() ?? '';

            // 如果有错误码且不是成功码，抛出异常
            if (errorCode != null && errorCode != '0' && errorCode.isNotEmpty) {
              print(
                  '⚠️ CozeAI: SSE流中检测到服务端错误: code=$errorCode, message=$errorMessage');
              throw CozeAPIException(
                '服务暂时不可用，请稍后重试',
                code: 'SERVICE_ERROR_$errorCode',
                originalError: errorMessage,
              );
            }
          }
        }

        // 只有answer类型的事件才包含实际内容
        if (eventType == 'answer') {
          answerEventCount++;
          final answer = _tryExtractAnswer(jsonData);

          if (answer != null && answer.isNotEmpty) {
            buffer.write(answer);
          }
        }
      } catch (e) {
        // 如果是我们主动抛出的 CozeAPIException，重新抛出
        if (e is CozeAPIException) {
          rethrow;
        }
        // 其他解析错误静默处理
        continue;
      }
    }

    final result = buffer.toString();
    print(
        '✅ CozeAI: SSE解析完成: $eventCount个事件, $answerEventCount个answer事件, 提取${result.length}字符');

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
    // 检查配置（洞察智能体使用独立的 Token）
    if (EnvConfig.cozeInsightApiToken.isEmpty ||
        EnvConfig.cozeInsightProjectId.isEmpty) {
      throw CozeAPIException(
        '洞察智能体配置未完成，请在 .env 文件中配置 COZE_INSIGHT_API_TOKEN 和 COZE_INSIGHT_PROJECT_ID',
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
      // 仅上传用户记录内容（record_time + content），不拼接本地提示词
      final userRecords = records
          .map((r) => {
                'record_time': r.recordTime.trim(),
                'content': r.content.trim(),
              })
          .where((item) => (item['content'] as String).isNotEmpty)
          .toList();

      if (userRecords.isEmpty) {
        throw CozeAPIException(
          '记录内容为空，无法生成洞察',
          code: 'EMPTY_INPUT',
        );
      }

      final userInputText = jsonEncode(userRecords);

      // 调用洞察 API
      final responseText = await _callInsightAPI(userInputText);

      print('✅ CozeAI: 收到洞察响应，长度: ${responseText.length}');
      print('📝 CozeAI: 洞察原始响应:\n$responseText');

      // 解析响应
      final report =
          _parseInsightResponse(responseText, weekRange, records.length);

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
  /// [userInputText] 必须是用户记录内容，不额外拼接系统提示词
  Future<String> _callInsightAPI(String userInputText) async {
    // 创建单独的 Dio 实例用于洞察 API（使用独立的 Token）
    final insightDio = Dio();
    final baseUrl = EnvConfig.cozeInsightBaseUrl;
    insightDio.options.baseUrl = baseUrl;
    insightDio.options.connectTimeout = AppConstants.cozeApiTimeout;
    insightDio.options.receiveTimeout =
        const Duration(seconds: 120); // 洞察可能需要更长时间
    insightDio.options.headers = {
      'Authorization': 'Bearer ${EnvConfig.cozeInsightApiToken}',
      'Content-Type': 'application/json',
    };

    // 生成唯一的 session_id
    final sessionId = _uuid.v4().replaceAll('-', '');

    print('🔄 CozeAI: 发送洞察请求');
    print('   Base URL: $baseUrl');
    print('   Full URL: $baseUrl/stream_run');
    print('   Session ID: $sessionId');
    print('   Project ID: ${EnvConfig.cozeInsightProjectId}');
    print(
        '   Token configured: ${EnvConfig.cozeInsightApiToken.isNotEmpty ? "是 (${EnvConfig.cozeInsightApiToken.substring(0, 10)}...)" : "否"}');

    final projectIdStr = EnvConfig.cozeInsightProjectId;
    final projectId = int.tryParse(projectIdStr);

    if (projectId == null || projectId <= 0) {
      throw CozeAPIException(
        '洞察智能体 Project ID 配置无效: $projectIdStr',
        code: 'CONFIG_ERROR',
      );
    }

    try {
      final response = await insightDio.post(
        '/stream_run',
        data: {
          'content': {
            'query': {
              'prompt': [
                {
                  'type': 'text',
                  'content': {'text': userInputText},
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
        print('📥 CozeAI: 收到洞察流式响应，长度: ${streamText.length}');

        final answer = _extractAnswerFromSSE(streamText);
        return answer.isNotEmpty ? answer : streamText;
      }

      throw CozeAPIException(
        '洞察API响应无效: HTTP ${response.statusCode}',
        code: 'INVALID_RESPONSE',
      );
    } on DioException catch (e) {
      print('❌ CozeAI: 洞察API请求失败');
      print('   Status: ${e.response?.statusCode}');
      print('   Message: ${e.message}');
      print('   Response: ${e.response?.data}');
      rethrow;
    }
  }

  /// 解析洞察响应
  InsightReport _parseInsightResponse(
      String responseText, String weekRange, int recordCount) {
    try {
      // 尝试从响应中提取 JSON
      var jsonText = _extractJsonFromText(responseText);
      print('🔍 CozeAI: 提取的洞察JSON:\n$jsonText');

      // 尝试修复常见的 JSON 格式问题
      jsonText = _repairInsightJson(jsonText);

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

  /// 修复洞察 JSON 中的常见格式问题
  /// 例如：{"key": "value": "xxx"} -> {"key": "need", "value": "xxx"}
  String _repairInsightJson(String jsonText) {
    // 修复 highlight_tags 中的格式问题
    // 问题格式: {"key": "value": "实际值"}
    // 正确格式: {"key": "need", "value": "实际值"}

    // 匹配 {"key": "value": "xxx"} 这种错误格式
    final pattern1 = RegExp(r'\{"key":\s*"value":\s*"([^"]+)"\}');
    jsonText = jsonText.replaceAllMapped(pattern1, (match) {
      final value = match.group(1);
      return '{"key": "need", "value": "$value"}';
    });

    // 匹配 {"key": "trigger": "xxx"} 这种错误格式（如果存在）
    final pattern2 = RegExp(r'\{"key":\s*"trigger":\s*"([^"]+)"\}');
    jsonText = jsonText.replaceAllMapped(pattern2, (match) {
      final value = match.group(1);
      return '{"key": "trigger", "value": "$value"}';
    });

    // 修复可能的 Unicode 字符截断问题（移除不完整的 UTF-8 序列末尾）
    // 如果 JSON 以不完整的中文字符结尾，尝试截断到最后一个完整的 JSON 结构
    if (!jsonText.trimRight().endsWith('}')) {
      // 找到最后一个完整的 } 位置
      final lastBrace = jsonText.lastIndexOf('}');
      if (lastBrace > 0) {
        jsonText = jsonText.substring(0, lastBrace + 1);
        print('🔧 CozeAI: 修复了不完整的 JSON 末尾');
      }
    }

    return jsonText;
  }

  /// 解析洞察 JSON
  InsightReport _parseInsightJson(
    Map<String, dynamic> json,
    String weekRange,
    int recordCount,
  ) {
    // 解析情绪概览
    final emotionOverviewData =
        json['emotion_overview'] as Map<String, dynamic>?;
    final emotionOverview = EmotionOverview(
      summary:
          emotionOverviewData?['summary']?.toString() ?? '本周记录不足，无法生成完整的情绪分析。',
    );

    // 解析高频情境
    final highFrequencyList =
        json['high_frequency_emotions'] as List<dynamic>? ?? [];
    final highFrequencyEmotions = highFrequencyList.map((item) {
      final map = item as Map<String, dynamic>;
      return HighFrequencyEmotion(
        content: map['content']?.toString() ?? '',
        time: map['time']?.toString() ?? '',
      );
    }).toList();

    // 解析模式假设
    final patternData = json['pattern_hypothesis'] as Map<String, dynamic>?;
    final highlightTagsList =
        patternData?['highlight_tags'] as List<dynamic>? ?? [];
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

  List<String> _splitTagText(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'^[\[\(\{（【\s]+|[\]\)\}）】\s]+$'), '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceAll('"', '');

    if (cleaned.isEmpty) return [];

    return cleaned
        .split(RegExp(r'[，,、；;|/\\\n]+'))
        .map((e) => e.trim())
        .map((e) => e.replaceFirst(RegExp(r'^\d+\s*[.、\-)\]]\s*'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  IntensityLevel _parseIntensity(dynamic rawIntensity) {
    final intensity = rawIntensity is num
        ? rawIntensity.toInt()
        : int.tryParse(rawIntensity?.toString() ?? '');

    switch (intensity) {
      case 1:
        return IntensityLevel.veryLow;
      case 2:
        return IntensityLevel.low;
      case 4:
        return IntensityLevel.high;
      case 5:
        return IntensityLevel.veryHigh;
      default:
        return IntensityLevel.medium;
    }
  }

  List<Feeling> _normalizeFeelingsField(dynamic feelingsField) {
    final result = <Feeling>[];
    final seen = <String>{};

    void appendFeeling(String rawText, IntensityLevel intensity) {
      for (final token in _splitTagText(rawText)) {
        if (seen.add(token)) {
          result.add(Feeling(feeling: token, intensity: intensity));
        }
      }
    }

    if (feelingsField is List) {
      for (final item in feelingsField) {
        if (item is Map) {
          final text = item['feeling']?.toString() ??
              item['emotion']?.toString() ??
              item['name']?.toString() ??
              '';
          if (text.isNotEmpty) {
            appendFeeling(text, _parseIntensity(item['intensity']));
          }
        } else if (item != null) {
          appendFeeling(item.toString(), IntensityLevel.medium);
        }
      }
    } else if (feelingsField is String) {
      appendFeeling(feelingsField, IntensityLevel.medium);
    }

    return result;
  }

  List<Need> _normalizeNeedsField(dynamic needsField) {
    final result = <Need>[];
    final seen = <String>{};

    void appendNeed(String rawText, String reason) {
      for (final token in _splitTagText(rawText)) {
        if (seen.add(token)) {
          result.add(Need(need: token, reason: reason));
        }
      }
    }

    if (needsField is List) {
      for (final item in needsField) {
        if (item is Map) {
          final text = item['need']?.toString() ??
              item['name']?.toString() ??
              item['value']?.toString() ??
              '';
          final reason = item['reason']?.toString() ?? '';
          if (text.isNotEmpty) {
            appendNeed(text, reason);
          }
        } else if (item != null) {
          appendNeed(item.toString(), '');
        }
      }
    } else if (needsField is String) {
      appendNeed(needsField, '');
    }

    return result;
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

    // 感受/需要：如果返回值中包含分隔符，自动拆为多个独立标签
    final feelingsField = json['feelings'] ?? json['感受'] ?? json['情绪'];
    final needsField = json['needs'] ?? json['需要'] ?? json['需求'];
    final feelings = _normalizeFeelingsField(feelingsField);
    final needs = _normalizeNeedsField(needsField);

    // 请求：支持多种字段名和格式
    String? request;
    final requestsField =
        json['requests'] ?? json['请求'] ?? json['建议'] ?? json['request'];
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

    // 推荐的深入分析方法（合并进 NVC 智能体的分诊字段，可选）
    final recommendedMethodRaw =
        json['recommended_method'] ?? json['recommendedMethod'] ?? json['推荐方法'];
    final recommendedMethod = recommendedMethodRaw?.toString().trim();

    return NVCAnalysis(
      observation: observation,
      feelings: feelings,
      needs: needs,
      request: request,
      insight: insight,
      recommendedMethod:
          (recommendedMethod?.isEmpty ?? true) ? null : recommendedMethod,
      analyzedAt: DateTime.now(),
    );
  }

  /// 生成日总结
  ///
  /// 分析当天的所有记录，生成情绪关键词、一句话概括和分数
  ///
  /// [records] 当天的记录列表，格式为 [{record_time, content}, ...]
  /// [date] 日期
  /// 返回 DailySummary 对象
  Future<DailySummary> generateDailySummary(
    List<DailySummaryRecord> records,
    DateTime date,
  ) async {
    // 检查配置
    if (!EnvConfig.isDailySummaryConfigured) {
      throw CozeAPIException(
        '日总结智能体配置未完成',
        code: 'CONFIG_ERROR',
      );
    }

    // 检查记录数量（至少需要 2 条）
    if (records.length < 2) {
      throw CozeAPIException(
        '记录数量不足，至少需要 2 条记录才能生成日总结',
        code: 'INSUFFICIENT_RECORDS',
      );
    }

    print('📅 CozeAI: 开始生成日总结，记录数: ${records.length}');

    try {
      // 构建输入数据
      final inputData = records
          .map((r) => {
                'record_time': r.recordTime,
                'content': r.content,
              })
          .toList();

      final inputText = jsonEncode(inputData);

      // 调用 API
      final responseText = await _callDailySummaryAPI(inputText);

      print('✅ CozeAI: 收到日总结响应，长度: ${responseText.length}');
      print('📝 CozeAI: 日总结原始响应:\n$responseText');

      // 解析响应
      final summary =
          _parseDailySummaryResponse(responseText, date, records.length);

      print('✅ CozeAI: 日总结生成完成');
      print('📊 CozeAI: 情绪关键词: ${summary.moodWord}');
      print('📊 CozeAI: 一句话概括: ${summary.oneSentence}');
      print('📊 CozeAI: 分数: ${summary.score}');

      return summary;
    } on DioException catch (e) {
      throw CozeAPIException.fromDioError(e);
    } catch (e) {
      if (e is CozeAPIException) rethrow;
      throw CozeAPIException(
        '日总结生成失败: $e',
        code: 'DAILY_SUMMARY_ERROR',
        originalError: e,
      );
    }
  }

  /// 调用日总结 API（SSE流式响应）
  Future<String> _callDailySummaryAPI(String inputText) async {
    // 创建单独的 Dio 实例
    final dailySummaryDio = Dio();
    final baseUrl = EnvConfig.cozeDailySummaryBaseUrl;
    dailySummaryDio.options.baseUrl = baseUrl;
    dailySummaryDio.options.connectTimeout = AppConstants.cozeApiTimeout;
    dailySummaryDio.options.receiveTimeout = const Duration(seconds: 60);
    dailySummaryDio.options.headers = {
      'Authorization': 'Bearer ${EnvConfig.cozeDailySummaryApiToken}',
      'Content-Type': 'application/json',
    };

    // 生成唯一的 session_id
    final sessionId = _uuid.v4().replaceAll('-', '');

    print('🔄 CozeAI: 发送日总结请求');
    print('   Base URL: $baseUrl');
    print('   Session ID: $sessionId');

    final projectIdStr = EnvConfig.cozeDailySummaryProjectId;
    final projectId = int.tryParse(projectIdStr);

    if (projectId == null || projectId <= 0) {
      throw CozeAPIException(
        '日总结智能体 Project ID 配置无效: $projectIdStr',
        code: 'CONFIG_ERROR',
      );
    }

    try {
      final response = await dailySummaryDio.post(
        '/stream_run',
        data: {
          'content': {
            'query': {
              'prompt': [
                {
                  'type': 'text',
                  'content': {'text': inputText},
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
        // 逐行解析 SSE，遇到 message_end / [DONE] 立即停止读取，
        // 避免因流未关闭而永远挂起。兜底超时 45s。
        final streamText = await _readSSEStreamUntilDone(
          response.data.stream,
          timeout: const Duration(seconds: 45),
        );
        print('📥 CozeAI: 收到日总结流式响应，长度: ${streamText.length}');

        final answer = _extractAnswerFromSSE(streamText);
        return answer.isNotEmpty ? answer : streamText;
      }

      throw CozeAPIException(
        '日总结API响应无效: HTTP ${response.statusCode}',
        code: 'INVALID_RESPONSE',
      );
    } on DioException catch (e) {
      print('❌ CozeAI: 日总结API请求失败');
      print('   Status: ${e.response?.statusCode}');
      print('   Message: ${e.message}');
      rethrow;
    }
  }

  /// 逐行读取 SSE 流，遇到终止信号（message_end / [DONE]）立即返回，
  /// 不等流物理关闭，从根本上避免连接未关闭时的永久挂起。
  ///
  /// [timeout] 兜底超时：流一直没有终止信号时强制结束，抛 CozeAPIException。
  Future<String> _readSSEStreamUntilDone(
    Stream<List<int>> byteStream, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();
    final completer = Completer<String>();
    StreamSubscription<List<int>>? subscription;
    Timer? timeoutTimer;

    void done() {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      subscription?.cancel();
      completer.complete(buffer.toString());
    }

    void onError(Object e, [StackTrace? st]) {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      subscription?.cancel();
      completer.completeError(e, st);
    }

    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError(
          CozeAPIException(
            '日总结流式响应超时（${timeout.inSeconds}s），请检查网络连接',
            code: 'STREAM_TIMEOUT',
          ),
        );
      }
    });

    subscription = byteStream.listen(
      (chunk) {
        // 追加到行缓冲，逐行解析
        final decoded = utf8.decode(chunk, allowMalformed: true);
        for (final char in decoded.split('')) {
          if (char == '\n') {
            final line = lineBuffer.toString().trim();
            lineBuffer.clear();
            buffer.writeln(line);

            // 判断终止信号
            if (line.startsWith('data:')) {
              final data = line.substring(5).trim();
              if (data == '[DONE]') {
                done();
                return;
              }
              // message_end 事件 → 流内容已完整
              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                if (json['type'] == 'message_end') {
                  done();
                  return;
                }
              } catch (_) {
                // 非 JSON 行，继续
              }
            }
          } else {
            lineBuffer.write(char);
          }
        }
      },
      onDone: done,
      onError: onError,
      cancelOnError: false,
    );

    return completer.future;
  }

  /// 解析日总结响应
  DailySummary _parseDailySummaryResponse(
    String responseText,
    DateTime date,
    int recordCount,
  ) {
    try {
      // 尝试从响应中提取 JSON
      final jsonText = _extractJsonFromText(responseText);
      print('🔍 CozeAI: 提取的日总结JSON:\n$jsonText');

      final jsonData = jsonDecode(jsonText) as Map<String, dynamic>;

      // 解析字段
      final moodWord = jsonData['mood_word']?.toString() ?? '平静';
      final oneSentence = jsonData['one_sentence']?.toString() ?? '今日无特别记录';

      // 解析分数，确保在 0-10 范围内
      int score = 5;
      if (jsonData['score'] != null) {
        if (jsonData['score'] is int) {
          score = jsonData['score'] as int;
        } else if (jsonData['score'] is double) {
          score = (jsonData['score'] as double).round();
        } else {
          score = int.tryParse(jsonData['score'].toString()) ?? 5;
        }
        // 确保分数在有效范围内
        score = score.clamp(0, 10);
      }

      return DailySummary(
        date: DateTime(date.year, date.month, date.day),
        moodWord: moodWord,
        oneSentence: oneSentence,
        score: score,
        recordCount: recordCount,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      print('⚠️ CozeAI: 日总结JSON解析失败: $e');
      print('⚠️ CozeAI: 原始响应: $responseText');

      // 如果解析失败，返回默认值
      if (responseText.contains('error') || responseText.length < 20) {
        throw CozeAPIException(
          'AI服务暂时不可用，请稍后重试',
          code: 'SERVICE_ERROR',
          originalError: e,
        );
      }

      throw CozeAPIException(
        '日总结响应格式异常，无法解析',
        code: 'PARSE_ERROR',
        originalError: e,
      );
    }
  }

  // ==================== 深入分析（一方法一智能体，输出结构同构） ====================

  /// 五个深入分析方法的元信息（标题/标签/理论来源/概述 + 解析兜底值）
  static const Map<
      String,
      ({
        String title,
        String label,
        String theory,
        String overview,
        String observedLabel,
        String truthLabel,
        String kind,
      })> _deepMethodMeta = {
    'selfCompassion': (
      title: '自我关怀与滋养',
      label: 'Self-Compassion & Savoring',
      theory: '源自自我关怀与正向心理学',
      overview: '难受时，陪你停止自我攻击；美好时，帮你把这份好放大、留住。',
      observedLabel: '你对自己说的话',
      truthLabel: '但其实',
      kind: 'self_kindness',
    ),
    'cognitiveReframe': (
      title: '想法校准',
      label: 'CBT',
      theory: '源自经典认知行为学派',
      overview: '帮助你把事实与脑中迅速出现的判断分开，减少被“我不行”这样的结论拖走。',
      observedLabel: '你脑中的结论',
      truthLabel: '事实是',
      kind: 'thought_check',
    ),
    'releaseControl': (
      title: '放下控制',
      label: 'ACT',
      theory: '源自第三波认知行为疗法',
      overview: '帮助你不再急着解决每一个念头，在无法确定时也能先回到当下。',
      observedLabel: '缠着你的念头',
      truthLabel: '松开一点看',
      kind: 'defusion',
    ),
    'boundarySupport': (
      title: '稳住情绪',
      label: 'DBT',
      theory: '源自第三波认知行为疗法',
      overview: '帮助你先降低情绪强度，再用清楚、稳定的方式表达边界。',
      observedLabel: '上头那一刻',
      truthLabel: '这股情绪在说',
      kind: 'steady_express',
    ),
    'gentleRecovery': (
      title: '慢慢带回自己',
      label: 'Behavioral Activation',
      theory: '源自行为主义与 CBT 干预传统',
      overview: '帮助你从微小行动重新接回节律、感受和生活里的恢复感。',
      observedLabel: '最近的信号',
      truthLabel: '这其实说明',
      kind: 'tiny_recharge',
    ),
  };

  /// 深入分析（通用入口）
  ///
  /// [methodType] 为 DeeperSupportType 的 name；
  /// 按方法路由到各自的智能体，输出结构同构（自我关怀额外带 face 双面）。
  Future<DeepAnalysisResult> generateDeepAnalysis({
    required String methodType,
    required String transcription,
  }) async {
    final meta = _deepMethodMeta[methodType];
    if (meta == null) {
      throw CozeAPIException(
        '未知的深入分析方法: $methodType',
        code: 'CONFIG_ERROR',
      );
    }

    final config = EnvConfig.deepAnalysisConfigFor(methodType);
    if (config == null ||
        config.token.isEmpty ||
        config.baseUrl.isEmpty ||
        config.projectId.isEmpty) {
      throw CozeAPIException(
        '「${meta.title}」智能体配置未完成，请在 .env 中补全对应的 COZE_DEEP_* 配置',
        code: 'CONFIG_ERROR',
      );
    }

    print('🫶 CozeAI: 开始深入分析（${meta.title}），输入长度: ${transcription.length}');

    try {
      final responseText = await _callDeepAnalysisAPI(config, transcription);
      print('✅ CozeAI: 收到深入分析响应，长度: ${responseText.length}');

      final result = parseDeepAnalysisResponse(methodType, responseText);
      print('✅ CozeAI: 深入分析解析完成（${meta.title}），face: ${result.face}');
      return result;
    } on DioException catch (e) {
      throw CozeAPIException.fromDioError(e);
    } catch (e) {
      if (e is CozeAPIException) rethrow;
      throw CozeAPIException(
        '深入分析生成失败: $e',
        code: 'DEEP_ANALYSIS_ERROR',
        originalError: e,
      );
    }
  }

  /// 调用深入分析 API（SSE 流式响应），配置由调用方按方法传入
  Future<String> _callDeepAnalysisAPI(
    ({String token, String baseUrl, String projectId}) config,
    String inputText,
  ) async {
    final deepAnalysisDio = Dio();
    final baseUrl = config.baseUrl;
    deepAnalysisDio.options.baseUrl = baseUrl;
    deepAnalysisDio.options.connectTimeout = AppConstants.cozeApiTimeout;
    deepAnalysisDio.options.receiveTimeout = const Duration(seconds: 60);
    deepAnalysisDio.options.headers = {
      'Authorization': 'Bearer ${config.token}',
      'Content-Type': 'application/json',
    };

    final sessionId = _uuid.v4().replaceAll('-', '');

    final projectId = int.tryParse(config.projectId);
    if (projectId == null || projectId <= 0) {
      throw CozeAPIException(
        '深入分析智能体 Project ID 配置无效: ${config.projectId}',
        code: 'CONFIG_ERROR',
      );
    }

    print('🔄 CozeAI: 发送深入分析请求');
    print('   Base URL: $baseUrl');
    print('   Session ID: $sessionId');

    try {
      final response = await deepAnalysisDio.post(
        '/stream_run',
        data: {
          'content': {
            'query': {
              'prompt': [
                {
                  'type': 'text',
                  'content': {'text': inputText},
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
        final streamText = await _readSSEStreamUntilDone(
          response.data.stream,
          timeout: const Duration(seconds: 45),
        );
        final answer = _extractAnswerFromSSE(streamText);
        return answer.isNotEmpty ? answer : streamText;
      }

      throw CozeAPIException(
        '深入分析API响应无效: HTTP ${response.statusCode}',
        code: 'INVALID_RESPONSE',
      );
    } on DioException catch (e) {
      print('❌ CozeAI: 深入分析API请求失败');
      print('   Status: ${e.response?.statusCode}');
      print('   Message: ${e.message}');
      rethrow;
    }
  }

  /// 解析深入分析智能体响应 → DeepAnalysisResult（五方法同构）
  ///
  /// 智能体输出结构见产品定义：
  /// { method, [face], enough_signal, analysis: { trigger, core: { observed, truth },
  ///   emotions }, response: { resonance, insight, micro_action, self_statement } }
  /// face 仅自我关怀与滋养输出（low/high 双面），其余方法无此字段。
  /// 保持为公开的纯解析入口，便于用固定样本验证智能体协议兼容性。
  DeepAnalysisResult parseDeepAnalysisResponse(
    String methodType,
    String responseText,
  ) {
    final meta = _deepMethodMeta[methodType]!;
    final data = _decodeAgentJsonObject(responseText);

    Map<String, dynamic> asMap(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

    final analysisMap = asMap(data['analysis']);
    final core = asMap(analysisMap['core']);
    final observed = asMap(core['observed']);
    final truth = asMap(core['truth']);
    final responseMap = asMap(data['response']);
    final microAction = asMap(responseMap['micro_action']);

    final faceRaw = data['face']?.toString();
    String? face = (faceRaw == 'high' || faceRaw == 'low') ? faceRaw : null;
    if (methodType == 'selfCompassion') {
      face ??= 'low'; // 自我关怀必有面向，缺失时按低谷兜底
    }
    final isHigh = face == 'high';

    String? nullIfEmpty(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    // 兼容 0-10 与 0-100 两种强度制
    final emotions = ((analysisMap['emotions'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final raw = (item['intensity'] as num?)?.toDouble() ?? 50;
          final scaled = raw <= 10 ? raw * 10 : raw;
          return DeepEmotion(
            name: item['name']?.toString() ?? '',
            intensity: scaled.round().clamp(0, 100),
          );
        })
        .where((item) => item.name.isNotEmpty)
        .toList();

    // 自我关怀的兜底随 face 切换，其余方法用各自元信息里的固定值
    final observedLabelFallback = methodType == 'selfCompassion' && isHigh
        ? '你匆匆带过的好'
        : meta.observedLabel;
    final truthLabelFallback =
        methodType == 'selfCompassion' && isHigh ? '而这份好里' : meta.truthLabel;
    final kindFallback =
        methodType == 'selfCompassion' && isHigh ? 'savoring' : meta.kind;

    return DeepAnalysisResult(
      type: methodType,
      title: meta.title,
      methodLabel: meta.label,
      theorySource: meta.theory,
      overview: meta.overview,
      stuckPoint: nullIfEmpty(observed['value']) ?? '',
      groundedUnderstanding: nullIfEmpty(responseMap['insight']) ?? '',
      oneSmallStep: nullIfEmpty(microAction['text']) ?? '',
      steadySentence: nullIfEmpty(responseMap['self_statement']) ?? '',
      analyzedAt: DateTime.now(),
      face: face,
      enoughSignal: data['enough_signal'] as bool? ?? true,
      resonance: nullIfEmpty(responseMap['resonance']),
      emotions: emotions,
      observedLabel: nullIfEmpty(observed['label']) ?? observedLabelFallback,
      observedValue: nullIfEmpty(observed['value']),
      truthLabel: nullIfEmpty(truth['label']) ?? truthLabelFallback,
      truthValue: nullIfEmpty(truth['value']),
      microActionKind: nullIfEmpty(microAction['kind']) ?? kindFallback,
    );
  }

  /// 兼容智能体直接返回业务 JSON，以及 OpenAI 兼容接口的
  /// choices[0].message.content 外壳。
  Map<String, dynamic> _decodeAgentJsonObject(String responseText) {
    final jsonText = _extractJsonFromText(responseText);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('智能体响应不是 JSON 对象');
    }

    final outer = Map<String, dynamic>.from(decoded);
    final assistantContent = _extractAssistantContent(outer);
    if (assistantContent == null) return outer;
    if (assistantContent is Map) {
      return Map<String, dynamic>.from(assistantContent);
    }
    if (assistantContent is String && assistantContent.trim().isNotEmpty) {
      final innerText = _extractJsonFromText(assistantContent);
      final inner = jsonDecode(innerText);
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
    }

    throw const FormatException('智能体 message.content 中没有有效 JSON');
  }

  dynamic _extractAssistantContent(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final firstChoice = choices.first;
    if (firstChoice is! Map) return null;
    final message = firstChoice['message'];
    if (message is! Map) return null;

    final content = message['content'];
    if (content is! List) return content;

    final buffer = StringBuffer();
    for (final item in content) {
      if (item is String) {
        buffer.write(item);
      } else if (item is Map) {
        final text = item['text'] ?? item['content'];
        if (text != null) buffer.write(text);
      }
    }
    return buffer.toString();
  }
}

/// 日总结请求记录
class DailySummaryRecord {
  final String recordTime;
  final String content;

  const DailySummaryRecord({
    required this.recordTime,
    required this.content,
  });
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
