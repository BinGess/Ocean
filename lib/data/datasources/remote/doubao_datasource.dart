/// 豆包远程数据源
/// 封装豆包 API 调用

import 'dart:typed_data';
import '../../../core/network/doubao_asr_client.dart';
import '../../../core/network/doubao_llm_client.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/weekly_insight.dart';

class DoubaoDataSource {
  final DoubaoASRClient asrClient;
  final DoubaoLLMClient llmClient;

  DoubaoDataSource({
    required this.asrClient,
    required this.llmClient,
  });

  /// 语音转文本
  ///
  /// [audioData] 音频数据（PCM 16kHz 16bit mono）
  /// [appKey] API App Key
  /// [accessKey] API Access Key
  /// [resourceId] 资源 ID
  Future<String> transcribeAudio({
    required Uint8List audioData,
    required String appKey,
    required String accessKey,
    required String resourceId,
  }) async {
    // 连接 WebSocket
    await asrClient.connect(
      appKey: appKey,
      accessKey: accessKey,
      resourceId: resourceId,
    );

    String transcription = '';
    bool isComplete = false;

    // 监听响应
    final subscription = asrClient.responses.listen((response) {
      if (response.success && response.text != null) {
        transcription = response.text!;
        if (response.isFinal) {
          isComplete = true;
        }
      }
    });

    // 分块发送音频（200ms per chunk = 6400 bytes @ 16kHz 16bit mono）
    const chunkSize = 6400;
    for (var i = 0; i < audioData.length; i += chunkSize) {
      final end = (i + chunkSize < audioData.length)
          ? i + chunkSize
          : audioData.length;
      final chunk = audioData.sublist(i, end);
      await asrClient.sendAudio(chunk);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 发送结束标记
    await asrClient.finishAudio();

    // 等待最终结果
    while (!isComplete) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 清理
    await subscription.cancel();
    await asrClient.disconnect();

    return transcription;
  }

  /// NVC 分析
  Future<NVCAnalysis?> analyzeWithNVC({
    required String transcription,
    String? context,
  }) async {
    final response = await llmClient.analyzeWithNVC(
      transcription: transcription,
      context: context,
    );

    if (response.success && response.content != null) {
      try {
        // 解析 JSON 响应
        final json = response.content!;
        // TODO: 实现 NVCAnalysis.fromJsonString
        // return NVCAnalysis.fromJsonString(json);
        return null; // 暂时返回 null
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// 生成周洞察
  Future<WeeklyInsight?> generateWeeklyInsight({
    required List<Record> records,
    required String weekRange,
  }) async {
    final response = await llmClient.generateWeeklyInsight(
      records: records,
      weekRange: weekRange,
    );

    if (response.success && response.content != null) {
      try {
        // 解析 JSON 响应
        final json = response.content!;
        // TODO: 实现 WeeklyInsight.fromJsonString
        // return WeeklyInsight.fromJsonString(json);
        return null; // 暂时返回 null
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// 推荐需要
  Future<List<String>> recommendNeeds({
    required List<String> moods,
  }) async {
    final response = await llmClient.recommendNeeds(moods: moods);

    if (response.success && response.content != null) {
      try {
        // 解析 JSON 响应
        // TODO: 实现解析逻辑
        return [];
      } catch (e) {
        return [];
      }
    }

    return [];
  }
}
