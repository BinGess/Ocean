// ignore_for_file: invalid_annotation_target

/// 周洞察实体
/// 对应 TypeScript 的 WeeklyInsight 模型

import 'package:freezed_annotation/freezed_annotation.dart';

part 'weekly_insight.freezed.dart';
part 'weekly_insight.g.dart';

/// 情绪模式
@freezed
class EmotionalPattern with _$EmotionalPattern {
  const factory EmotionalPattern({
    required String pattern,
    required String description,
    required List<String> relatedRecords,
    @JsonKey(name: 'user_feedback') String? userFeedback, // 'like' | 'dislike' | 'uncertain'
  }) = _EmotionalPattern;

  factory EmotionalPattern.fromJson(Map<String, dynamic> json) =>
      _$EmotionalPatternFromJson(json);
}

/// 微实验
@freezed
class MicroExperiment with _$MicroExperiment {
  const factory MicroExperiment({
    required String id,
    required String suggestion,
    required String rationale,
    @JsonKey(name: 'related_needs') List<String>? relatedNeeds,
    required DateTime createdAt,
    String? status, // 'pending' | 'in_progress' | 'completed'
    String? feedback,
  }) = _MicroExperiment;

  factory MicroExperiment.fromJson(Map<String, dynamic> json) =>
      _$MicroExperimentFromJson(json);
}

/// 需要统计
@freezed
class NeedStatistics with _$NeedStatistics {
  const factory NeedStatistics({
    required String need,
    required int count,
    required double percentage,
  }) = _NeedStatistics;

  factory NeedStatistics.fromJson(Map<String, dynamic> json) =>
      _$NeedStatisticsFromJson(json);
}

/// 周洞察实体
@freezed
class WeeklyInsight with _$WeeklyInsight {
  const factory WeeklyInsight({
    required String id,

    /// 周范围（例如："2025-01-13 ~ 2025-01-19"）
    @JsonKey(name: 'week_range') required String weekRange,

    /// 开始日期
    @JsonKey(name: 'start_date') required DateTime startDate,

    /// 结束日期
    @JsonKey(name: 'end_date') required DateTime endDate,

    /// 情绪模式列表
    @JsonKey(name: 'emotional_patterns') required List<EmotionalPattern> emotionalPatterns,

    /// 微实验列表
    @JsonKey(name: 'micro_experiments') required List<MicroExperiment> microExperiments,

    /// 需要统计
    @JsonKey(name: 'need_statistics') List<NeedStatistics>? needStatistics,

    /// AI 总结
    @JsonKey(name: 'ai_summary') String? aiSummary,

    /// 引用的记录 ID 列表
    @JsonKey(name: 'referenced_records') List<String>? referencedRecords,

    /// 创建时间
    @JsonKey(name: 'created_at') required DateTime createdAt,

    /// 更新时间
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _WeeklyInsight;

  factory WeeklyInsight.fromJson(Map<String, dynamic> json) =>
      _$WeeklyInsightFromJson(json);
}
