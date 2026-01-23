/// 记录仓储实现
/// 使用 Hive 进行本地存储

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/day_aggregation.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/record.dart';
import '../../domain/repositories/record_repository.dart';
import '../datasources/local/hive_database.dart';
import '../models/record_model.dart';

class RecordRepositoryImpl implements RecordRepository {
  final HiveDatabase database;

  RecordRepositoryImpl({required this.database});

  @override
  Future<Record> createQuickNote({
    required String transcription,
    String? audioUrl,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
  }) async {
    final now = DateTime.now();
    final record = Record(
      id: const Uuid().v4(),
      type: RecordType.quickNote,
      transcription: transcription,
      createdAt: now,
      updatedAt: now,
      audioUrl: audioUrl,
      duration: duration,
      processingMode: processingMode,
      moods: moods,
      needs: needs,
    );
    return _putRecord(record);
  }

  @override
  Future<Record> createJournal({
    required String transcription,
    String? title,
    String? summary,
    List<String>? referencedFragments,
  }) async {
    final now = DateTime.now();
    final record = Record(
      id: const Uuid().v4(),
      type: RecordType.journal,
      transcription: transcription,
      createdAt: now,
      updatedAt: now,
      title: title,
      summary: summary,
      date: _dayKey(now),
      referencedFragments: referencedFragments,
    );
    return _putRecord(record);
  }

  @override
  Future<Record> createWeeklyRecord({
    required String transcription,
    required String weekRange,
    List<String>? referencedRecords,
  }) async {
    final now = DateTime.now();
    final record = Record(
      id: const Uuid().v4(),
      type: RecordType.weekly,
      transcription: transcription,
      createdAt: now,
      updatedAt: now,
      weekRange: weekRange,
      referencedRecords: referencedRecords,
    );
    return _putRecord(record);
  }

  @override
  Future<Record?> getRecordById(String id) async {
    final model = database.recordsBox.get(id);
    return model?.toEntity();
  }

  @override
  Future<List<Record>> getAllRecords() async {
    final models = database.recordsBox.values.toList();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Record>> getRecordsByType(RecordType type) async {
    final records = await getAllRecords();
    return records.where((r) => r.type == type).toList();
  }

  @override
  Future<List<Record>> getRecordsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return getRecordsByDateRange(start, end);
  }

  @override
  Future<List<Record>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final models = database.recordsBox.values
        .where((m) =>
            !m.createdAt.isBefore(start) && m.createdAt.isBefore(end))
        .toList();

    // 按创建时间降序排序
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<DayAggregation?> getDayAggregation(String dayKey) async {
    final date = _parseDayKey(dayKey);
    if (date == null) {
      return null;
    }
    final records = await getRecordsByDate(date);
    if (records.isEmpty) {
      return null;
    }

    final moodCount = <String, int>{};
    final needCount = <String, int>{};
    double totalDuration = 0;
    String? journalId;

    for (final r in records) {
      if (r.duration != null) {
        totalDuration += r.duration!;
      }
      if (r.type == RecordType.journal) {
        journalId = r.id;
      }
      for (final mood in (r.moods ?? const <String>[])) {
        moodCount[mood] = (moodCount[mood] ?? 0) + 1;
      }
      for (final need in (r.needs ?? const <String>[])) {
        needCount[need] = (needCount[need] ?? 0) + 1;
      }
    }

    final dominantMoods = _topKeys(moodCount, limit: 3);
    final dominantNeeds = _topKeys(needCount, limit: 3);

    return DayAggregation(
      dayKey: dayKey,
      date: DateTime(date.year, date.month, date.day),
      records: records,
      dominantMoods: dominantMoods.isEmpty ? null : dominantMoods,
      dominantNeeds: dominantNeeds.isEmpty ? null : dominantNeeds,
      totalRecords: records.length,
      totalDuration: totalDuration == 0 ? null : totalDuration,
      hasJournal: journalId != null,
      journalId: journalId,
    );
  }

  @override
  Future<List<DayAggregation>> getDayAggregations(
      DateTime start, DateTime end) async {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    if (endDate.isBefore(startDate)) {
      return [];
    }

    final result = <DayAggregation>[];
    for (var d = startDate;
        !d.isAfter(endDate);
        d = d.add(const Duration(days: 1))) {
      final agg = await getDayAggregation(_dayKey(d));
      if (agg != null) {
        result.add(agg);
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<Record> updateRecord(Record record) async {
    return _putRecord(record);
  }

  @override
  Future<Record> updateProcessingMode(String id, ProcessingMode mode) async {
    final current = await getRecordById(id);
    if (current == null) {
      throw StateError('Record not found: $id');
    }
    final updated = current.copyWith(
      processingMode: mode,
      updatedAt: DateTime.now(),
    );
    return _putRecord(updated);
  }

  @override
  Future<Record> updateNVCAnalysis(String id, dynamic nvcAnalysis) async {
    final current = await getRecordById(id);
    if (current == null) {
      throw StateError('Record not found: $id');
    }

    NVCAnalysis? parsed;
    if (nvcAnalysis is NVCAnalysis) {
      parsed = nvcAnalysis;
    } else if (nvcAnalysis is Map<String, dynamic>) {
      parsed = NVCAnalysis.fromJson(nvcAnalysis);
    } else if (nvcAnalysis is String) {
      final decoded = jsonDecode(nvcAnalysis);
      if (decoded is Map<String, dynamic>) {
        parsed = NVCAnalysis.fromJson(decoded);
      }
    }

    final updated = current.copyWith(
      nvc: parsed,
      updatedAt: DateTime.now(),
    );
    return _putRecord(updated);
  }

  @override
  Future<void> deleteRecord(String id) async {
    await database.recordsBox.delete(id);
  }

  @override
  Future<List<Record>> searchRecords(String query) async {
    final lowerQuery = query.toLowerCase();
    final models = database.recordsBox.values
        .where((m) => m.transcription.toLowerCase().contains(lowerQuery))
        .toList();

    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Record>> getRecentRecords({int limit = 10}) async {
    final records = await getAllRecords();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records.take(limit).toList();
  }

  Future<Record> _putRecord(Record record) async {
    final model = RecordModel.fromEntity(record);
    await database.recordsBox.put(record.id, model);
    return model.toEntity();
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseDayKey(String dayKey) {
    final parts = dayKey.split('-');
    if (parts.length != 3) {
      return null;
    }
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) {
      return null;
    }
    return DateTime(y, m, d);
  }

  List<String> _topKeys(Map<String, int> counts, {int limit = 3}) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }
}
