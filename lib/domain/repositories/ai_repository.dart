// AI 仓储接口（Repository Interface）
// 定义语音识别和 AI 分析相关的契约

import '../entities/nvc_analysis.dart';
import '../entities/weekly_insight.dart';
import '../entities/insight_report.dart';

abstract class AIRepository {
  /// 语音转文字（从文件）
  /// [audioPath] 音频文件路径
  /// 返回值：识别后的文本
  Future<String> transcribeAudioFile(String audioPath);

  /// 语音转文字（从音频流）
  /// [audioStream] 音频数据流
  /// 返回值：识别后的文本
  Future<String> transcribeAudioStream(Stream<List<int>> audioStream);

  /// NVC 分析
  /// [transcription] 转录文本
  /// 返回值：NVC 分析结果
  Future<NVCAnalysis> analyzeWithNVC(String transcription);

  /// 情绪识别
  /// [transcription] 转录文本
  /// 返回值：识别到的情绪列表
  Future<List<String>> identifyMoods(String transcription);

  /// 需要识别
  /// [transcription] 转录文本
  /// 返回值：识别到的需要列表
  Future<List<String>> identifyNeeds(String transcription);

  /// 生成日记标题
  /// [transcription] 转录文本
  /// 返回值：建议的标题
  Future<String> generateJournalTitle(String transcription);

  /// 生成日记摘要
  /// [transcription] 转录文本
  /// 返回值：摘要文本
  Future<String> generateJournalSummary(String transcription);

  /// 生成周洞察
  /// [records] 本周的记录列表
  /// 返回值：周洞察
  Future<WeeklyInsight> generateWeeklyInsight(List<String> recordIds);

  /// 分析情绪模式
  /// [recordIds] 记录 ID 列表
  /// 返回值：识别到的情绪模式
  Future<List<EmotionalPattern>> analyzeEmotionalPatterns(
      List<String> recordIds);

  /// 生成微实验建议
  /// [needStatistics] 需要统计数据
  /// 返回值：微实验建议列表
  Future<List<MicroExperiment>> generateMicroExperiments(
      List<String> dominantNeeds);

  /// 生成洞察报告（新版）
  /// [records] 记录列表（包含时间和内容）
  /// [weekRange] 周范围
  /// 返回值：洞察报告
  Future<InsightReport> generateInsightReport(
    List<InsightRequestRecord> records,
    String weekRange,
  );

  /// 检查 API 配置是否完整
  bool isConfigured();
}
