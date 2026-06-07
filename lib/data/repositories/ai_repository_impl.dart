/// AI 仓储实现
/// 使用豆包 API 进行语音识别和 NVC 分析
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
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
    if (kDebugMode && EnvConfig.isMockApiEnabled) {
      debugPrint('AIRepository: 使用本地 Mock 转写结果');
      return _buildMockTranscription();
    }

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
    if (kDebugMode && EnvConfig.isMockApiEnabled) {
      debugPrint('AIRepository: 使用本地 Mock 流式转写结果');
      return _buildMockTranscription();
    }

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
    if (kDebugMode && EnvConfig.isMockApiEnabled) {
      debugPrint('AIRepository: 使用本地 Mock NVC 分析');
      return _buildMockNVCAnalysis(transcription);
    }

    Exception? lastError;

    // 优先使用 Coze AI 进行 NVC 洞察
    if (cozeAIService != null && EnvConfig.isCozeConfigured) {
      try {
        debugPrint('AIRepository: 使用 Coze AI 进行 NVC 洞察');
        return await cozeAIService!.analyzeNVC(transcription);
      } catch (e) {
        debugPrint('AIRepository: Coze AI 分析失败: $e');
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
      debugPrint('AIRepository: 豆包LLM分析失败: $e');
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

    debugPrint('AIRepository: 开始生成洞察报告');
    return await cozeAIService!.generateInsight(records, weekRange);
  }

  @override
  bool isConfigured() {
    return EnvConfig.isConfigured;
  }

  String _buildMockTranscription() {
    return '今天有点累，也有点烦，感觉事情很多都压在一起了，我想先把自己稳住。';
  }

  NVCAnalysis _buildMockNVCAnalysis(String transcription) {
    final text = transcription.trim();
    final lowerText = text.toLowerCase();

    if (_containsAny(
      lowerText,
      ['开心', '满足', '放松', '轻松', '平静', '很美', '喜欢', '踏实', '被自己美到'],
    )) {
      return NVCAnalysis(
        observation: text.isEmpty
            ? '你提到自己注意到了当下不错的状态，也在认真感受这一刻。'
            : '你在描述一个让自己觉得舒服、满意或被滋养到的片刻。',
        feelings: const [
          Feeling(feeling: '开心', intensity: IntensityLevel.medium),
          Feeling(feeling: '满足', intensity: IntensityLevel.medium),
        ],
        needs: const [
          Need(need: '自我认同', reason: '你在意自己是否能看见并接住自己的美好感受。'),
          Need(need: '愉悦感', reason: '你想把这一刻的轻松和舒展留住。'),
        ],
        request: '如果你愿意，可以把这一刻最让你喜欢的一个细节记下来，让它成为今天的锚点。',
        insight: '这段话里不只是“开心”，更像是你终于和自己站在同一边，允许自己感到好。',
        analyzedAt: DateTime.now(),
      );
    }

    if (_containsAny(
      lowerText,
      ['累', '烦', '焦虑', '崩', '压力', '委屈', '难受', '担心', '害怕', '生气', '压'],
    )) {
      return NVCAnalysis(
        observation: text.isEmpty
            ? '你在描述一段让自己持续消耗的状态。'
            : '你在说一件已经明显牵动你情绪和身体反应的事，像是有很多东西同时压了上来。',
        feelings: const [
          Feeling(feeling: '焦虑', intensity: IntensityLevel.high),
          Feeling(feeling: '疲惫', intensity: IntensityLevel.high),
          Feeling(feeling: '委屈', intensity: IntensityLevel.medium),
        ],
        needs: const [
          Need(need: '支持', reason: '你可能不只是在解决事情，也在扛住很多没有被分担的压力。'),
          Need(need: '清晰', reason: '当事情堆在一起时，你需要先分清楚现在最重要的是什么。'),
          Need(need: '休息', reason: '你的状态像是在提醒你，能量已经被消耗得有点多了。'),
        ],
        request: '先别急着把所有问题一起解决，只问自己一件事：此刻最需要先减轻的是哪一部分？',
        insight: '这段表达里，真正让你难受的可能不只是事情本身，而是你已经一个人撑了太久。',
        analyzedAt: DateTime.now(),
      );
    }

    return NVCAnalysis(
      observation: text.isEmpty
          ? '你在试着描述自己现在的状态，也在找一种更能理解自己的方式。'
          : '你在整理一段让你在意的经历，同时也在努力弄清自己到底怎么了。',
      feelings: const [
        Feeling(feeling: '在意', intensity: IntensityLevel.medium),
        Feeling(feeling: '困惑', intensity: IntensityLevel.medium),
      ],
      needs: const [
        Need(need: '理解', reason: '你希望自己不是被情绪推着走，而是真的看懂发生了什么。'),
        Need(need: '方向感', reason: '当感受还没被说清时，你也会更难知道下一步该怎么做。'),
      ],
      request: '先用一句最简单的话补完它：我现在最不想再继续承受的，究竟是什么？',
      insight: '很多时候，能把自己说清一点点，本身就是从混乱里往回走的一步。',
      analyzedAt: DateTime.now(),
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}
