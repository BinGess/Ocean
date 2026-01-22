/// 豆包 LLM (大语言模型) 客户端
/// 用于 NVC 分析和周洞察生成

import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../../domain/entities/record.dart';
import '../../domain/entities/weekly_insight.dart';

/// LLM 响应
class LLMResponse {
  final bool success;
  final String? content;
  final String? error;
  final Map<String, dynamic>? rawData;

  LLMResponse({
    required this.success,
    this.content,
    this.error,
    this.rawData,
  });
}

/// 豆包 LLM 客户端
class DoubaoLLMClient {
  final Dio _dio;
  final String apiKey;
  final String endpoint;

  DoubaoLLMClient({
    required this.apiKey,
    this.endpoint = 'https://ark.cn-beijing.volces.com/api/v3',
  }) : _dio = Dio(BaseOptions(
          baseUrl: endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  /// 分析文本并提取 NVC 结构
  ///
  /// [transcription] 语音转写文本
  /// [context] 额外上下文（可选）
  Future<LLMResponse> analyzeWithNVC({
    required String transcription,
    String? context,
  }) async {
    final prompt = _buildNVCPrompt(transcription, context);

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'doubao-pro-32k', // 或其他豆包模型
          'messages': [
            {
              'role': 'system',
              'content': '你是一个专业的情绪分析助手，擅长使用非暴力沟通（NVC）框架帮助用户理解自己的情绪和需要。'
                  '你需要从用户的表达中提取：观察（客观事实）、感受（情绪）、需要（底层需求）、请求（具体行动）。'
                  '请以 JSON 格式返回分析结果。',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
          'response_format': {'type': 'json_object'},
        },
      );

      final content = response.data['choices']?[0]?['message']?['content'];

      return LLMResponse(
        success: true,
        content: content,
        rawData: response.data,
      );
    } on DioException catch (e) {
      return LLMResponse(
        success: false,
        error: e.message ?? 'Network error',
      );
    } catch (e) {
      return LLMResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 生成周洞察
  ///
  /// [records] 本周的所有记录
  /// [weekRange] 周范围（例如："2025-01-13 ~ 2025-01-19"）
  Future<LLMResponse> generateWeeklyInsight({
    required List<Record> records,
    required String weekRange,
  }) async {
    final prompt = _buildWeeklyInsightPrompt(records, weekRange);

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'doubao-pro-128k', // 使用更大的上下文窗口
          'messages': [
            {
              'role': 'system',
              'content': '你是一个专业的心理洞察助手，擅长从用户一周的情绪记录中发现模式、识别需要，并提出具体的改善建议（微实验）。'
                  '请分析用户的情绪模式，识别重复出现的感受和需要，并提出 2-3 个可行的微实验建议。'
                  '请以 JSON 格式返回分析结果。',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.8,
          'max_tokens': 4000,
          'response_format': {'type': 'json_object'},
        },
      );

      final content = response.data['choices']?[0]?['message']?['content'];

      return LLMResponse(
        success: true,
        content: content,
        rawData: response.data,
      );
    } on DioException catch (e) {
      return LLMResponse(
        success: false,
        error: e.message ?? 'Network error',
      );
    } catch (e) {
      return LLMResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 推荐需要
  ///
  /// [moods] 情绪列表
  Future<LLMResponse> recommendNeeds({
    required List<String> moods,
  }) async {
    final prompt = '''
请根据以下情绪，推荐可能未被满足的需要（基于 NVC 框架）：

情绪：${moods.join('、')}

请返回 JSON 格式：
{
  "needs": ["需要1", "需要2", "需要3"],
  "reasoning": "推荐理由"
}
''';

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'doubao-pro-32k',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个 NVC（非暴力沟通）专家，擅长从情绪推断底层需要。',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
          'response_format': {'type': 'json_object'},
        },
      );

      final content = response.data['choices']?[0]?['message']?['content'];

      return LLMResponse(
        success: true,
        content: content,
        rawData: response.data,
      );
    } on DioException catch (e) {
      return LLMResponse(
        success: false,
        error: e.message ?? 'Network error',
      );
    } catch (e) {
      return LLMResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 构建 NVC 分析提示词
  String _buildNVCPrompt(String transcription, String? context) {
    return '''
请分析以下文本，使用非暴力沟通（NVC）框架提取结构化信息：

文本：$transcription
${context != null ? '\n额外上下文：$context' : ''}

请以 JSON 格式返回：
{
  "observation": "客观观察到的事实（不包含评判）",
  "feelings": [
    {
      "feeling": "情绪名称",
      "intensity": 1-5 (强度)
    }
  ],
  "needs": ["需要1", "需要2"],
  "request": "具体的请求或行动（如果有）",
  "summary": "简短总结"
}
''';
  }

  /// 构建周洞察提示词
  String _buildWeeklyInsightPrompt(List<Record> records, String weekRange) {
    final recordsSummary = records.map((r) {
      return {
        'date': r.createdAt.toString().substring(0, 10),
        'transcription': r.transcription,
        'moods': r.moods,
        'needs': r.needs,
      };
    }).toList();

    return '''
请分析用户 $weekRange 这一周的情绪记录，提供深度洞察：

记录列表：
${json.encode(recordsSummary)}

请以 JSON 格式返回：
{
  "emotional_patterns": [
    {
      "pattern": "模式描述",
      "description": "详细说明",
      "related_records": ["记录ID1", "记录ID2"]
    }
  ],
  "micro_experiments": [
    {
      "suggestion": "微实验建议",
      "rationale": "理由",
      "related_needs": ["需要1", "需要2"]
    }
  ],
  "need_statistics": [
    {
      "need": "需要名称",
      "count": 出现次数,
      "percentage": 百分比
    }
  ],
  "ai_summary": "整体总结和鼓励"
}
''';
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
