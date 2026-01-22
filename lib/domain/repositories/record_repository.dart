/// 记录仓储接口（Repository Interface）
/// 定义记录相关的数据访问契约

import '../entities/record.dart';
import '../entities/day_aggregation.dart';

abstract class RecordRepository {
  /// 创建碎片记录
  Future<Record> createQuickNote({
    required String transcription,
    String? audioUrl,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
  });

  /// 创建日记
  Future<Record> createJournal({
    required String transcription,
    String? title,
    String? summary,
    List<String>? referencedFragments,
  });

  /// 创建周记
  Future<Record> createWeeklyRecord({
    required String transcription,
    required String weekRange,
    List<String>? referencedRecords,
  });

  /// 获取单条记录
  Future<Record?> getRecordById(String id);

  /// 获取所有记录
  Future<List<Record>> getAllRecords();

  /// 获取指定类型的记录
  Future<List<Record>> getRecordsByType(RecordType type);

  /// 获取指定日期的记录
  Future<List<Record>> getRecordsByDate(DateTime date);

  /// 获取日期范围内的记录
  Future<List<Record>> getRecordsByDateRange(DateTime start, DateTime end);

  /// 获取日卡（按日期聚合）
  Future<DayAggregation?> getDayAggregation(String dayKey);

  /// 获取日期范围内的日卡列表
  Future<List<DayAggregation>> getDayAggregations(DateTime start, DateTime end);

  /// 更新记录
  Future<Record> updateRecord(Record record);

  /// 更新处理模式
  Future<Record> updateProcessingMode(String id, ProcessingMode mode);

  /// 更新 NVC 分析结果
  Future<Record> updateNVCAnalysis(String id, dynamic nvcAnalysis);

  /// 删除记录
  Future<void> deleteRecord(String id);

  /// 搜索记录（按文本内容）
  Future<List<Record>> searchRecords(String query);

  /// 获取最近的记录
  Future<List<Record>> getRecentRecords({int limit = 10});
}
