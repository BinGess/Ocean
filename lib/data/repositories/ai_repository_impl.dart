/// AI 仓储实现
/// 使用豆包 API 进行语音识别和 NVC 分析

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/weekly_insight.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/remote/doubao_datasource.dart';
import '../../core/constants/app_constants.dart';

class AIRepositoryImpl implements AIRepository {
  final DoubaoDataSource doubaoDataSource;

  AIRepositoryImpl({required this.doubaoDataSource});

  @override
  Future<String> transcribeAudioFile(String audioPath) async {
    final file = File(audioPath);
    final bytes = await file.readAsBytes();
    return _transcribeAudioBytes(Uint8List.fromList(bytes));
  }

  @override
  Future<String> transcribeAudioStream(Stream<List<int>> audioStream) async {
    final buffer = <int>[];
    await for (final chunk in audioStream) {
      buffer.addAll(chunk);
    }
    return _transcribeAudioBytes(Uint8List.fromList(buffer));
  }

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) async {
    try {
      final analysis = await doubaoDataSource.analyzeWithNVC(
        transcription: transcription,
      );
      if (analysis != null) {
        return analysis;
      }
    } catch (_) {}

    return NVCAnalysis(
      observation: transcription,
      feelings: const [],
      needs: const [],
      analyzedAt: DateTime.now(),
    );
  }

  @override
  Future<List<String>> identifyMoods(String transcription) async {
    return [];
  }

  @override
  Future<List<String>> identifyNeeds(String transcription) async {
    return [];
  }

  @override
  Future<String> generateJournalTitle(String transcription) async {
    final trimmed = transcription.trim();
    if (trimmed.isEmpty) {
      return '日记';
    }
    return trimmed.length <= 16 ? trimmed : '${trimmed.substring(0, 16)}…';
  }

  @override
  Future<String> generateJournalSummary(String transcription) async {
    final trimmed = transcription.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 80)}…';
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight(List<String> recordIds) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    final weekRange = '${_dateKey(start)} ~ ${_dateKey(now)}';
    return WeeklyInsight(
      id: const Uuid().v4(),
      weekRange: weekRange,
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(now.year, now.month, now.day),
      emotionalPatterns: const [],
      microExperiments: const [],
      needStatistics: const [],
      aiSummary: null,
      referencedRecords: recordIds,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<List<EmotionalPattern>> analyzeEmotionalPatterns(
      List<String> recordIds) async {
    return [];
  }

  @override
  Future<List<MicroExperiment>> generateMicroExperiments(
      List<String> dominantNeeds) async {
    final now = DateTime.now();
    return dominantNeeds.take(3).map((need) {
      return MicroExperiment(
        id: const Uuid().v4(),
        suggestion: '围绕“$need”做一个小尝试',
        rationale: '用最小成本验证这个需要是否能被更好满足',
        relatedNeeds: [need],
        createdAt: now,
        status: 'pending',
        feedback: null,
      );
    }).toList();
  }

  @override
  bool isConfigured() {
    return EnvConfig.isConfigured;
  }

  Future<String> _transcribeAudioBytes(Uint8List audioData) async {
    if (EnvConfig.doubaoAsrAppKey.isEmpty ||
        EnvConfig.doubaoAsrAccessKey.isEmpty) {
      return '';
    }

    try {
      return await doubaoDataSource.transcribeAudio(
        audioData: audioData,
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
    } catch (e) {
      return '';
    }
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
