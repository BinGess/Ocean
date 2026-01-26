/// AI 仓储实现
/// 使用豆包 API 进行语音识别和 NVC 分析

import 'dart:io';
import 'dart:typed_data';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/weekly_insight.dart';
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
      final audioBytes = await audioFile.readAsBytes();

      // 调用转写服务
      return await doubaoDataSource.transcribeAudio(
        audioData: Uint8List.fromList(audioBytes),
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
    } catch (e) {
      return '语音转写失败: $e';
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

      // 转写音频
      return await doubaoDataSource.transcribeAudio(
        audioData: Uint8List.fromList(audioData),
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
    } catch (e) {
      return '语音转写失败: $e';
    }
  }

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) async {
    // 优先使用 Coze AI 进行 NVC 洞察
    if (cozeAIService != null && EnvConfig.isCozeConfigured) {
      try {
        print('🤖 AIRepository: 使用 Coze AI 进行 NVC 洞察');
        return await cozeAIService!.analyzeNVC(transcription);
      } catch (e) {
        print('⚠️ AIRepository: Coze AI 分析失败，降级到豆包LLM: $e');
        // 降级到豆包 LLM
      }
    }

    // 降级：使用豆包 LLM
    try {
      final result = await doubaoDataSource.analyzeWithNVC(
        transcription: transcription,
      );
      return result ?? _createDefaultNVC(transcription);
    } catch (e) {
      print('⚠️ AIRepository: 豆包LLM分析失败，返回默认结果: $e');
      return _createDefaultNVC(transcription);
    }
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
  bool isConfigured() {
    return EnvConfig.isConfigured;
  }

  /// 创建默认的 NVC 分析结果
  NVCAnalysis _createDefaultNVC(String transcription) {
    return NVCAnalysis(
      observation: transcription,
      feelings: const [],
      needs: const [],
      analyzedAt: DateTime.now(),
    );
  }
}
