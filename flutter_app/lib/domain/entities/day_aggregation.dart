/// 日卡（Day Aggregation）实体
/// 按日期聚合的记录集合，用于日历视图展示

import 'package:freezed_annotation/freezed_annotation.dart';
import 'record.dart';

part 'day_aggregation.freezed.dart';
part 'day_aggregation.g.dart';

/// 日卡实体
@freezed
class DayAggregation with _$DayAggregation {
  const factory DayAggregation({
    /// 日期 key (YYYY-MM-DD)
    required String dayKey,

    /// 日期对象
    required DateTime date,

    /// 当天的所有记录
    required List<Record> records,

    /// 当天的主要情绪（出现最多的情绪）
    List<String>? dominantMoods,

    /// 当天的主要需要
    List<String>? dominantNeeds,

    /// 记录总数
    required int totalRecords,

    /// 总录音时长（秒）
    double? totalDuration,

    /// 是否有日记
    required bool hasJournal,

    /// 日记 ID（如果存在）
    String? journalId,
  }) = _DayAggregation;

  factory DayAggregation.fromJson(Map<String, dynamic> json) =>
      _$DayAggregationFromJson(json);
}

/// 日卡扩展方法
extension DayAggregationExtensions on DayAggregation {
  /// 是否是今天
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 是否是昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 获取碎片记录列表
  List<Record> get quickNotes {
    return records.where((r) => r.type == RecordType.quickNote).toList();
  }

  /// 获取日记
  Record? get journal {
    return records.firstWhere(
      (r) => r.type == RecordType.journal,
      orElse: () => null as Record,
    );
  }
}
