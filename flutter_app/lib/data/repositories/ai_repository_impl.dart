/// AI 仓储实现
/// 使用豆包 API 进行语音识别和 NVC 分析

import 'dart:typed_data';
import '../../domain/entities/record.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/remote/doubao_datasource.dart';
import '../../core/constants/app_constants.dart';

class AIRepositoryImpl implements AIRepository {
  final DoubaoDataSource doubaoDataSource;

  AIRepositoryImpl({required this.doubaoDataSource});

  @override
  Future<String> transcribeAudio(Uint8List audioData) async {
    try {
      return await doubaoDataSource.transcribeAudio(
        audioData: audioData,
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
    } catch (e) {
      // 出错时返回模拟转写（用于开发）
      return '语音转写失败: $e';
    }
  }

  @override
  Future<NVCAnalysis?> analyzeWithNVC(String transcription) async {
    try {
      return await doubaoDataSource.analyzeWithNVC(
        transcription: transcription,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<String>> recommendNeeds(List<String> moods) async {
    try {
      return await doubaoDataSource.recommendNeeds(moods: moods);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<String>> extractMoods(String transcription) async {
    // TODO: 实现情绪提取逻辑
    // 可以使用 LLM 或本地规则引擎
    return [];
  }
}
