// 创建快速笔记用例
// 负责音频录制、转写、分析和保存的完整流程

import 'dart:io';
import '../entities/record.dart';
import '../entities/nvc_analysis.dart';
import '../repositories/record_repository.dart';
import '../repositories/ai_repository.dart';
import 'base_usecase.dart';

class CreateQuickNoteParams {
  final String? audioPath;
  final ProcessingMode mode;
  final List<String>? selectedMoods;
  final String? transcription;
  final NVCAnalysis? nvcAnalysis;

  CreateQuickNoteParams({
    this.audioPath,
    required this.mode,
    this.selectedMoods,
    this.transcription,
    this.nvcAnalysis,
  });
}

class CreateQuickNoteUseCase extends UseCase<Record, CreateQuickNoteParams> {
  final RecordRepository recordRepository;
  final AIRepository aiRepository;

  CreateQuickNoteUseCase({
    required this.recordRepository,
    required this.aiRepository,
  });

  @override
  Future<Record> call(CreateQuickNoteParams params) async {
    // 1. 获取最终文本（优先使用显式文本，其次尝试音频转写）
    final transcription = params.transcription?.trim().isNotEmpty == true
        ? params.transcription!.trim()
        : (params.audioPath != null
            ? await aiRepository.transcribeAudioFile(params.audioPath!)
            : null);

    if (transcription == null || transcription.isEmpty) {
      throw Exception('缺少可保存的文本内容');
    }

    // 2. 计算音频时长（仅有音频时）
    double? duration;
    if (params.audioPath != null) {
      final audioFile = File(params.audioPath!);
      if (await audioFile.exists()) {
        final audioBytes = await audioFile.readAsBytes();
        duration = audioBytes.length / (16000 * 2); // 假设 16kHz 16bit
      }
    }

    // 3. 根据处理模式进行不同处理
    List<String>? moods;
    List<String>? needs;
    NVCAnalysis? nvc;

    switch (params.mode) {
      case ProcessingMode.onlyRecord:
        // 仅保存转写文本
        break;

      case ProcessingMode.withMood:
        // 保存转写文本 + 用户选择的情绪
        moods = params.selectedMoods;

        // 可选：根据情绪推荐需要
        if (moods != null && moods.isNotEmpty) {
          needs = await aiRepository.identifyNeeds(moods.join(', '));
        }
        break;

      case ProcessingMode.withNVC:
        // 完整 NVC 分析
        if (params.nvcAnalysis != null) {
          nvc = params.nvcAnalysis;
        } else {
          nvc = await aiRepository.analyzeWithNVC(transcription);
        }

        // 从 NVC 分析中提取情绪和需要
        if (nvc != null) {
          moods = nvc.feelings.map((f) => f.feeling).toList();
          needs = nvc.needs.map((n) => n.need).toList();
        }
        break;
    }

    // 4. 保存到数据库
    return await recordRepository.createQuickNote(
      transcription: transcription,
      audioUrl: params.audioPath,
      duration: duration,
      processingMode: params.mode,
      moods: moods,
      needs: needs,
      nvc: nvc,
    );
  }
}
