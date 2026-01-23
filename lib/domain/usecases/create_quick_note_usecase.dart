/// 创建快速笔记用例
/// 负责音频录制、转写、分析和保存的完整流程

import 'dart:io';
import 'package:uuid/uuid.dart';
import '../entities/record.dart';
import '../entities/nvc_analysis.dart';
import '../repositories/record_repository.dart';
import '../repositories/ai_repository.dart';
import 'base_usecase.dart';

class CreateQuickNoteParams {
  final String audioPath;
  final ProcessingMode mode;
  final List<String>? selectedMoods;

  CreateQuickNoteParams({
    required this.audioPath,
    required this.mode,
    this.selectedMoods,
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
    final audioFile = File(params.audioPath);
    final audioBytes = await audioFile.readAsBytes();
    final transcription = await aiRepository.transcribeAudioFile(params.audioPath);

    // 3. 计算音频时长（可以从文件元数据获取，这里简化处理）
    final duration = audioBytes.length / (16000 * 2); // 假设 16kHz 16bit

    // 4. 根据处理模式进行不同处理
    List<String>? moods;
    List<String>? needs;
    NVCAnalysis? nvc;

    switch (params.mode) {
      case ProcessingMode.onlyRecord:
        break;

      case ProcessingMode.withMood:
        moods = params.selectedMoods;
        break;

      case ProcessingMode.withNVC:
        nvc = await aiRepository.analyzeWithNVC(transcription);
        moods = nvc.feelings.map((f) => f.feeling).toList();
        needs = nvc.needs.map((n) => n.need).toList();
        break;
    }

    // 5. 创建记录
    final now = DateTime.now();
    final record = Record(
      id: const Uuid().v4(),
      type: RecordType.quickNote,
      transcription: transcription,
      createdAt: now,
      updatedAt: now,
      audioUrl: params.audioPath,
      duration: duration,
      processingMode: params.mode,
      moods: moods,
      needs: needs,
      nvc: nvc,
    );

    final created = await recordRepository.createQuickNote(
      transcription: record.transcription,
      audioUrl: record.audioUrl,
      duration: record.duration,
      processingMode: record.processingMode,
      moods: record.moods,
      needs: record.needs,
    );

    if (record.nvc == null) {
      return created;
    }

    return recordRepository.updateNVCAnalysis(created.id, record.nvc!.toJson());
  }
}
