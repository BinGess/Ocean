/// AI 仓储实现
/// 使用豆包 API 进行语音识别和 NVC 分析

import 'dart:io';
import 'dart:typed_data';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/weekly_insight.dart';
import '../../domain/entities/insight_report.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/remote/doubao_datasource.dart';
import '../../core/network/coze_ai_service.dart';
import '../../core/constants/app_constants.dart';

class AIRepositoryImpl implements AIRepository {
  final DoubaoDataSource doubaoDataSource;
  final CozeAIService? cozeAIService;

  AIRepositoryImpl({
    required this.doubaoDataSource,
    this.cozeAIService,
  });

  @override
  Future<String> transcribeAudioFile(String audioPath) async {
    try {
      // 读取音频文件
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在: $audioPath');
      }

      final audioBytes = await audioFile.readAsBytes();

      // 调用转写服务
      return await doubaoDataSource.transcribeAudio(
        audioData: Uint8List.fromList(audioBytes),
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
    } catch (e) {
      // 抛出异常而不是返回错误字符串,让调用方正确处理错误
      throw Exception('语音转写失败: $e');
    }
  }

  @override
  Future<String> transcribeAudioStream(Stream<List<int>> audioStream) async {
    try {
      // 收集流数据
      final List<int> audioData = [];
      await for (final chunk in audioStream) {
        audioData.addAll(chunk);
      }

      if (audioData.isEmpty) {
        throw Exception('音频数据为空');
      }

      // 转写音频
      return await doubaoDataSource.transcribeAudio(
        audioData: Uint8List.fromList(audioData),
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
    } catch (e) {
      // 抛出异常而不是返回错误字符串,让调用方正确处理错误
      throw Exception('语音转写失败: $e');
    }
  }

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) async {
    Exception? lastError;

    // 优先使用 Coze AI 进行 NVC 洞察
    if (cozeAIService != null && EnvConfig.isCozeConfigured) {
      try {
        print('🤖 AIRepository: 使用 Coze AI 进行 NVC 洞察');
        return await cozeAIService!.analyzeNVC(transcription);
      } catch (e) {
        print('⚠️ AIRepository: Coze AI 分析失败: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        // 降级到豆包 LLM
      }
    }

    // 降级：使用豆包 LLM
    try {
      final result = await doubaoDataSource.analyzeWithNVC(
        transcription: transcription,
      );
      if (result != null) {
        return result;
      }
    } catch (e) {
      print('⚠️ AIRepository: 豆包LLM分析失败: $e');
      lastError = e is Exception ? e : Exception(e.toString());
    }

    // 所有方法都失败了，抛出异常
    throw lastError ?? Exception('NVC分析失败：所有AI服务均不可用');
  }

  @override
  Future<List<String>> identifyMoods(String transcription) async {
    try {
      // TODO: 实现情绪识别
      // 可以调用 LLM 进行情绪识别
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<String>> identifyNeeds(String transcription) async {
    try {
      final result = await doubaoDataSource.recommendNeeds(moods: [transcription]);
      return result;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String> generateJournalTitle(String transcription) async {
    try {
      // TODO: 调用 LLM 生成标题
      return '日记 - ${DateTime.now().toString().substring(0, 10)}';
    } catch (e) {
      return '未命名日记';
    }
  }

  @override
  Future<String> generateJournalSummary(String transcription) async {
    try {
      // TODO: 调用 LLM 生成摘要
      if (transcription.length > 100) {
        return '${transcription.substring(0, 97)}...';
      }
      return transcription;
    } catch (e) {
      return transcription;
    }
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight(List<String> recordIds) async {
    // TODO: 实现周洞察生成
    // 需要先获取记录，然后调用 LLM 分析
    throw UnimplementedError('generateWeeklyInsight 暂未实现');
  }

  @override
  Future<List<EmotionalPattern>> analyzeEmotionalPatterns(
      List<String> recordIds) async {
    try {
      // TODO: 实现情绪模式分析
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<MicroExperiment>> generateMicroExperiments(
      List<String> dominantNeeds) async {
    try {
      // TODO: 实现微实验生成
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<InsightReport> generateInsightReport(
    List<InsightRequestRecord> records,
    String weekRange,
  ) async {
    // 检查配置
    if (cozeAIService == null || !EnvConfig.isInsightConfigured) {
      throw Exception('洞察智能体未配置，请检查环境变量');
    }

    print('🔮 AIRepository: 开始生成洞察报告');
    return await cozeAIService!.generateInsight(records, weekRange);
  }

  @override
  bool isConfigured() {
    return EnvConfig.isConfigured;
  }
}
