/// 应用核心常量配置

class AppConstants {
  // 应用信息
  static const String appName = 'MindFlow';
  static const String appVersion = '1.0.0';

  // 豆包语音识别 API 配置
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

  // UI 配置
  static const int maxRecentDays = 30; // 最近 N 天
  static const int weeklyInsightDays = 7; // 周洞察天数
}

/// 环境变量配置（需要从 .env 或配置文件读取）
class EnvConfig {
  // 豆包 ASR API
  static String get doubaoAsrAppKey =>
      const String.fromEnvironment('DOUBAO_ASR_APP_KEY', defaultValue: '');

  static String get doubaoAsrAccessKey =>
      const String.fromEnvironment('DOUBAO_ASR_ACCESS_KEY', defaultValue: '');

  static String get doubaoAsrResourceId =>
      const String.fromEnvironment('DOUBAO_ASR_RESOURCE_ID',
          defaultValue: 'volc.bigasr.sauc.duration');

  // 豆包 LLM API
  static String get doubaoLlmApiKey =>
      const String.fromEnvironment('DOUBAO_LLM_API_KEY', defaultValue: '');

  static String get doubaoModelId =>
      const String.fromEnvironment('DOUBAO_MODEL_ID', defaultValue: '');

  /// 验证配置是否完整
  static bool get isConfigured {
    return doubaoAsrAppKey.isNotEmpty &&
           doubaoAsrAccessKey.isNotEmpty &&
           doubaoLlmApiKey.isNotEmpty &&
           doubaoModelId.isNotEmpty;
  }
}
