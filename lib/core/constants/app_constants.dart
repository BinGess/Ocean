/// 应用核心常量配置
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // 应用信息
  static const String appName = 'MindFlow';
  static const String appVersion = '1.0.0';

  // 豆包语音识别 API 配置
  // 官方文档: https://www.volcengine.com/docs/6561/1354869
  static const String doubaoAsrEndpoint =
      'wss://openspeech.bytedance.com/api/v2/asr';

  // 豆包大模型 API 配置
  static const String doubaoLlmEndpoint =
      'https://ark.cn-beijing.volces.com/api/v3';

  // 本地存储配置
  static const String recordsBoxName = 'records';
  static const String weeklyInsightsBoxName = 'weekly_insights';
  static const String settingsBoxName = 'settings';

  // 音频配置
  static const int audioSampleRate = 16000;
  static const int audioBitRate = 16;
  static const int audioChannels = 1;
  static const int audioChunkDurationMs = 200; // 每包 200ms

  // API 超时配置
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration transcriptionTimeout = Duration(seconds: 60);

  // UI 配置
  static const int maxRecentDays = 30; // 最近 N 天
  static const int weeklyInsightDays = 7; // 周洞察天数
}

/// 环境变量配置（从 .env 文件读取）
class EnvConfig {
  // 豆包 ASR API
  static String get doubaoAsrAppKey =>
      dotenv.get('DOUBAO_ASR_APP_KEY', fallback: '').trim();

  static String get doubaoAsrAccessKey =>
      dotenv.get('DOUBAO_ASR_ACCESS_KEY', fallback: '').trim();

  static String get doubaoAsrResourceId =>
      dotenv.get('DOUBAO_ASR_RESOURCE_ID',
          fallback: 'volc.bigasr.sauc.duration').trim();

  // 豆包 LLM API
  static String get doubaoLlmApiKey =>
      dotenv.get('DOUBAO_LLM_API_KEY', fallback: '');

  static String get doubaoModelId =>
      dotenv.get('DOUBAO_MODEL_ID', fallback: 'doubao-pro-32k');

  /// 验证配置是否完整
  static bool get isConfigured {
    return doubaoAsrAppKey.isNotEmpty &&
           doubaoAsrAccessKey.isNotEmpty &&
           doubaoLlmApiKey.isNotEmpty &&
           doubaoModelId.isNotEmpty;
  }

  /// 获取配置状态信息（用于调试）
  static Map<String, dynamic> getConfigStatus() {
    return {
      'doubaoAsrAppKey': doubaoAsrAppKey.isEmpty ? '未配置' : '已配置 (${doubaoAsrAppKey.substring(0, 8)}...)',
      'doubaoAsrAccessKey': doubaoAsrAccessKey.isEmpty ? '未配置' : '已配置 (${doubaoAsrAccessKey.substring(0, 8)}...)',
      'doubaoAsrResourceId': doubaoAsrResourceId,
      'doubaoLlmApiKey': doubaoLlmApiKey.isEmpty ? '未配置' : '已配置 (${doubaoLlmApiKey.substring(0, 8)}...)',
      'doubaoModelId': doubaoModelId,
      'isConfigured': isConfigured,
    };
  }
}
