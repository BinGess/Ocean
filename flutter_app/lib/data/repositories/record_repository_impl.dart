/// 记录仓储实现
/// 使用 Hive 进行本地存储

import '../../domain/entities/record.dart';
import '../../domain/repositories/record_repository.dart';
import '../datasources/local/hive_database.dart';
import '../models/record_model.dart';

class RecordRepositoryImpl implements RecordRepository {
  final HiveDatabase database;

  RecordRepositoryImpl({required this.database});

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
