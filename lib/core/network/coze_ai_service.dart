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
    return '''请对以下文本进行NVC（非暴力沟通）分析：

文本内容：
$transcription

请从以下4个维度分析：
1. 观察（Observation）：客观描述发生了什么事情
2. 感受（Feelings）：识别当事人的情绪感受
3. 需要（Needs）：分析未被满足的核心需求
4. 请求（Requests）：具体可行的改进建议

请以JSON格式返回分析结果，格式如下：
{
  "observation": "客观观察的内容",
  "feelings": ["感受1", "感受2"],
  "needs": ["需要1", "需要2"],
  "requests": ["请求1", "请求2"]
}''';
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
      print('⚠️ CozeAI: JSON解析失败，使用降级策略: $e');
      print('⚠️ CozeAI: 原始响应文本: $responseText');
      // 降级：将整个响应作为观察内容
      return NVCAnalysis(
        observation: responseText,
        feelings: const [],
        needs: const [],
        analyzedAt: DateTime.now(),
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
      // 如果是列表，合并为一个字符串
      request = requestsField.map((e) => e.toString()).join('\n');
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
