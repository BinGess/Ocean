/// 应用核心常量配置
library;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // 应用信息
  static const String appName = '瞬记';
  static const String appVersion = '1.5';

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

  // Ocean backend
  static const String defaultOceanApiBaseUrl =
      'https://uunvcbiuhbet.sealoshzh.site';

  // UI 配置
  static const int maxRecentDays = 30; // 最近 N 天
  static const int weeklyInsightDays = 7; // 周洞察天数
}

/// 环境变量配置（从 .env 文件读取）
class EnvConfig {
  static bool get isMockApiEnabled =>
      dotenv.get('MOCK_API', fallback: 'false').trim().toLowerCase() == 'true';

  static bool get isMockProEnabled =>
      dotenv.get('MOCK_PRO', fallback: 'false').trim().toLowerCase() == 'true';

  // 豆包 ASR API
  static String get doubaoAsrAppKey =>
      dotenv.get('DOUBAO_ASR_APP_KEY', fallback: '').trim();

  static String get doubaoAsrAccessKey =>
      dotenv.get('DOUBAO_ASR_ACCESS_KEY', fallback: '').trim();

  static String get doubaoAsrResourceId =>
      dotenv.get('DOUBAO_ASR_RESOURCE_ID',
          fallback: 'volc.seedasr.sauc.duration').trim(); // 豆包2.0小时版

  static String get oceanApiBaseUrl => dotenv
      .get('OCEAN_API_BASE_URL', fallback: AppConstants.defaultOceanApiBaseUrl)
      .trim();

  // 豆包 LLM API
  static String get doubaoLlmApiKey =>
      dotenv.get('DOUBAO_LLM_API_KEY', fallback: '');

  static String get doubaoModelId =>
      dotenv.get('DOUBAO_MODEL_ID', fallback: 'doubao-pro-32k');

  // Coze AI (智能体) API
  static String get cozeApiToken =>
      dotenv.get('COZE_API_TOKEN', fallback: '').trim();

  static String get cozeBaseUrl =>
      dotenv.get('COZE_BASE_URL', fallback: 'https://qfcvbpvr72.coze.site').trim();

  static String get cozeProjectId =>
      dotenv.get('COZE_PROJECT_ID', fallback: '').trim();

  static String get cozeBotId =>
      dotenv.get('COZE_BOT_ID', fallback: '').trim();

  // Coze 洞察智能体配置（独立的 Token 和 URL）
  static String get cozeInsightApiToken =>
      dotenv.get('COZE_INSIGHT_API_TOKEN', fallback: '').trim();

  static String get cozeInsightBaseUrl =>
      dotenv.get('COZE_INSIGHT_BASE_URL', fallback: 'https://3my47k2yw9.coze.site').trim();

  static String get cozeInsightProjectId =>
      dotenv.get('COZE_INSIGHT_PROJECT_ID', fallback: '7600361830606815268').trim();

  // Coze 日总结智能体配置
  static String get cozeDailySummaryApiToken =>
      dotenv.get('COZE_DAILY_SUMMARY_API_TOKEN', fallback: 'eyJhbGciOiJSUzI1NiIsImtpZCI6Ijk0MTc4MjA4LTg3ZjUtNDNlMS1hNzNlLWIyYjE2ZDg2ZGYzMyJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbImdYZEpPREFPZ0Zia29oWjl3dHZzRmtyTU1UUlFTdmdvIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzcyMDE2MzA0LCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjEwNzIzNzYxNTU3MzQwMjAyIiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjEwNzUyMDc2OTEzNTczODk0In0.AndWEYHD41EM_eez7NDAs-MIHy3K0ALKbaVjAZVl8_Gt8yv6tEmukcuFhyo7CbTJErFT6hsKo8SdmE_9LxSwDlwEN569CP1moYZ6KULSTubR9QpF-t-1Rw-e5SV-DNBLioWzzyKyBxqMM4yhqpRGvVUnBzxjq2UyNLI3o8HV0ETB7j1O7s-0DeOSGisPKhmgkWBUauOGFnJo-VKdXworhMfBJn1M5y5jbr2xxil7o7GJUYYV4oCE1ABT4wLjnLKMp6PVkIfc62JzRkfjam0TV_5DEhvfDMUCDsrmM6-RIpdSowlpJlN-9BtuvR8u8UxeqgIN33Nm7k3y3iSVlkoSOg').trim();

  static String get cozeDailySummaryBaseUrl =>
      dotenv.get('COZE_DAILY_SUMMARY_BASE_URL', fallback: 'https://6n23cqs4qb.coze.site').trim();

  static String get cozeDailySummaryProjectId =>
      dotenv.get('COZE_DAILY_SUMMARY_PROJECT_ID', fallback: '7610722093646233641').trim();

  // Coze 深入分析智能体配置（自我关怀与滋养，token 只放 .env，不在源码留 fallback）
  static String get cozeDeepAnalysisApiToken =>
      dotenv.get('COZE_DEEP_ANALYSIS_API_TOKEN', fallback: '').trim();

  static String get cozeDeepAnalysisBaseUrl =>
      dotenv.get('COZE_DEEP_ANALYSIS_BASE_URL', fallback: 'https://fq5dmj28t8.coze.site').trim();

  static String get cozeDeepAnalysisProjectId =>
      dotenv.get('COZE_DEEP_ANALYSIS_PROJECT_ID', fallback: '').trim();

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
    return cozeInsightApiToken.isNotEmpty &&
           cozeInsightProjectId.isNotEmpty;
  }

  /// 验证日总结智能体配置是否完整
  static bool get isDailySummaryConfigured {
    return cozeDailySummaryApiToken.isNotEmpty &&
           cozeDailySummaryProjectId.isNotEmpty;
  }

  /// 验证深入分析智能体（自我关怀与滋养）配置是否完整
  static bool get isDeepAnalysisConfigured {
    return cozeDeepAnalysisApiToken.isNotEmpty &&
           cozeDeepAnalysisProjectId.isNotEmpty;
  }

  /// 按深入分析方法查询智能体配置（一方法一智能体）
  ///
  /// [methodType] 为 DeeperSupportType 的 name。
  /// 自我关怀与滋养沿用 COZE_DEEP_ANALYSIS_* 组；其余方法用 COZE_DEEP_{CBT|ACT|DBT|BA}_* 组。
  /// 未知方法返回 null。
  static ({String token, String baseUrl, String projectId})?
      deepAnalysisConfigFor(String methodType) {
    String env(String key) => dotenv.get(key, fallback: '').trim();

    switch (methodType) {
      case 'selfCompassion':
        return (
          token: cozeDeepAnalysisApiToken,
          baseUrl: cozeDeepAnalysisBaseUrl,
          projectId: cozeDeepAnalysisProjectId,
        );
      case 'cognitiveReframe':
        return (
          token: env('COZE_DEEP_CBT_API_TOKEN'),
          baseUrl: env('COZE_DEEP_CBT_BASE_URL'),
          projectId: env('COZE_DEEP_CBT_PROJECT_ID'),
        );
      case 'releaseControl':
        return (
          token: env('COZE_DEEP_ACT_API_TOKEN'),
          baseUrl: env('COZE_DEEP_ACT_BASE_URL'),
          projectId: env('COZE_DEEP_ACT_PROJECT_ID'),
        );
      case 'boundarySupport':
        return (
          token: env('COZE_DEEP_DBT_API_TOKEN'),
          baseUrl: env('COZE_DEEP_DBT_BASE_URL'),
          projectId: env('COZE_DEEP_DBT_PROJECT_ID'),
        );
      case 'gentleRecovery':
        return (
          token: env('COZE_DEEP_BA_API_TOKEN'),
          baseUrl: env('COZE_DEEP_BA_BASE_URL'),
          projectId: env('COZE_DEEP_BA_PROJECT_ID'),
        );
    }
    return null;
  }

  /// 指定方法的深入分析智能体是否已配置
  static bool isDeepAnalysisConfiguredFor(String methodType) {
    final config = deepAnalysisConfigFor(methodType);
    if (config == null) return false;
    return config.token.isNotEmpty &&
        config.baseUrl.isNotEmpty &&
        config.projectId.isNotEmpty;
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
