/// 记录仓储实现
/// 使用 Hive 进行本地存储

import '../../domain/entities/record.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/day_aggregation.dart';
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
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: RecordType.quickNote,
      transcription: transcription,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      audioUrl: audioUrl,
      duration: duration,
      processingMode: processingMode,
      moods: moods,
      needs: needs,
    );
    return await createRecord(record);
  }

  @override
  Future<Record> createJournal({
    required String transcription,
    String? title,
    String? summary,
    List<String>? referencedFragments,
  }) async {
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: RecordType.journal,
      transcription: transcription,
      title: title,
      summary: summary,
      referencedFragments: referencedFragments,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await createRecord(record);
  }

  @override
  Future<Record> createWeeklyRecord({
    required String transcription,
    required String weekRange,
    List<String>? referencedRecords,
  }) async {
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: RecordType.weekly,
      transcription: transcription,
      weekRange: weekRange,
      referencedRecords: referencedRecords,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await createRecord(record);
  }

  @override
  Future<List<Record>> getRecordsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getRecordsByDateRange(startOfDay, endOfDay);
  }

  @override
  Future<DayAggregation?> getDayAggregation(String dayKey) async {
    // TODO: 实现日聚合逻辑
    return null;
  }

  @override
  Future<List<DayAggregation>> getDayAggregations(DateTime start, DateTime end) async {
    // TODO: 实现日聚合列表
    return [];
  }

  @override
  Future<Record> updateProcessingMode(String id, ProcessingMode mode) async {
    final record = await getRecordById(id);
    if (record == null) throw Exception('Record not found');

    final updated = Record(
      id: record.id,
      type: record.type,
      transcription: record.transcription,
      createdAt: record.createdAt,
      updatedAt: DateTime.now(),
      processingMode: mode,
      audioUrl: record.audioUrl,
      duration: record.duration,
      moods: record.moods,
      needs: record.needs,
      nvc: record.nvc,
      title: record.title,
      summary: record.summary,
    );

    return await updateRecord(updated);
  }

  @override
  Future<Record> updateNVCAnalysis(String id, dynamic nvcAnalysis) async {
    final record = await getRecordById(id);
    if (record == null) throw Exception('Record not found');

    final updated = Record(
      id: record.id,
      type: record.type,
      transcription: record.transcription,
      createdAt: record.createdAt,
      updatedAt: DateTime.now(),
      nvc: nvcAnalysis as NVCAnalysis?,
      audioUrl: record.audioUrl,
      duration: record.duration,
      processingMode: record.processingMode,
      moods: record.moods,
      needs: record.needs,
      title: record.title,
      summary: record.summary,
    );

    return await updateRecord(updated);
  }

  @override
  Future<List<Record>> getRecentRecords({int limit = 10}) async {
    final allRecords = await getAllRecords();
    allRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allRecords.take(limit).toList();
  }

  @override
  Future<Record> createRecord(Record record) async {
    final model = RecordModel.fromEntity(record);
    await database.recordsBox.put(record.id, model);
    return model.toEntity();
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
    final typeString = type.toString().split('.').last;
    final models = database.recordsBox.values
        .where((m) => m.type == typeString)
        .toList();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Record>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final models = database.recordsBox.values
        .where((m) =>
            m.createdAt.isAfter(start) && m.createdAt.isBefore(end))
        .toList();

    // 按创建时间降序排序
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Record>> getRecordsForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getRecordsByDateRange(startOfDay, endOfDay);
  }

  @override
  Future<List<Record>> getRecordsForWeek(DateTime weekStart) async {
    final endOfWeek = weekStart.add(const Duration(days: 7));
    return getRecordsByDateRange(weekStart, endOfWeek);
  }

  @override
  Future<Record> updateRecord(Record record) async {
    final model = RecordModel.fromEntity(record);
    await database.recordsBox.put(record.id, model);
    return model.toEntity();
  }

  @override
  Future<void> deleteRecord(String id) async {
    await database.recordsBox.delete(id);
  }

  @override
  Future<int> getRecordsCount() async {
    return database.recordsBox.length;
  }

  @override
  Future<List<Record>> searchRecords(String query) async {
    final lowerQuery = query.toLowerCase();
    final models = database.recordsBox.values
        .where((m) => m.transcription.toLowerCase().contains(lowerQuery))
        .toList();

    return models.map((m) => m.toEntity()).toList();
  }
}
