/// 应用核心常量配置
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // 应用信息
  static const String appName = 'MindFlow';
  static const String appVersion = '1.0.0';

  // 豆包语音识别 API 配置
  // 官方文档: https://www.volcengine.com/docs/6561/1354869
  // 双向流式优化版（推荐）- 性能更优，只在结果变化时返回数据包
  static const String doubaoAsrEndpoint =
      'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async';

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
  static const Duration cozeApiTimeout = Duration(seconds: 30);
  static const Duration cozeReceiveTimeout = Duration(seconds: 60);

  // Coze AI 配置
  static const int cozeMaxRetries = 3;
  static const int cozeRetryDelaySeconds = 2;

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
          fallback: 'volc.seedasr.sauc.duration').trim(); // 豆包2.0小时版

  // 豆包 LLM API
  static String get doubaoLlmApiKey =>
      dotenv.get('DOUBAO_LLM_API_KEY', fallback: '');

  static String get doubaoModelId =>
      dotenv.get('DOUBAO_MODEL_ID', fallback: 'doubao-pro-32k');

  // Coze AI (智能体) API
  static String get cozeApiToken =>
      dotenv.get('COZE_API_TOKEN', fallback: '').trim();

  static String get cozeBaseUrl =>
      dotenv.get('COZE_BASE_URL', fallback: 'https://ypcqkgr32q.coze.site').trim();

  static String get cozeProjectId =>
      dotenv.get('COZE_PROJECT_ID', fallback: '').trim();

  static String get cozeBotId =>
      dotenv.get('COZE_BOT_ID', fallback: '').trim();

  // Coze 洞察智能体配置
  static String get cozeInsightBaseUrl =>
      dotenv.get('COZE_INSIGHT_BASE_URL', fallback: 'https://3my47k2yw9.coze.site').trim();

  static String get cozeInsightProjectId =>
      dotenv.get('COZE_INSIGHT_PROJECT_ID', fallback: '7600361830606815268').trim();

  /// 验证配置是否完整
  static bool get isConfigured {
    return doubaoAsrAppKey.isNotEmpty &&
           doubaoAsrAccessKey.isNotEmpty &&
           doubaoLlmApiKey.isNotEmpty &&
           doubaoModelId.isNotEmpty;
  }

  /// 验证 Coze AI 配置是否完整（只需要 API Token 和 Project ID）
  static bool get isCozeConfigured {
    return cozeApiToken.isNotEmpty &&
           cozeProjectId.isNotEmpty;
  }

  /// 验证洞察智能体配置是否完整
  static bool get isInsightConfigured {
    return cozeApiToken.isNotEmpty &&
           cozeInsightProjectId.isNotEmpty;
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
