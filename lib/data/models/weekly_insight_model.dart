/// 周洞察数据模型（Hive）
/// 用于本地存储的 WeeklyInsight 模型

import 'package:hive/hive.dart';
import '../../domain/entities/weekly_insight.dart';

part 'weekly_insight_model.g.dart';

@HiveType(typeId: 1)
class WeeklyInsightModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String weekRange;

  @HiveField(2)
  final DateTime startDate;

  @HiveField(3)
  final DateTime endDate;

  @HiveField(4)
  final List<Map<String, dynamic>> emotionalPatterns;

  @HiveField(5)
  final List<Map<String, dynamic>> microExperiments;

  @HiveField(6)
  final List<Map<String, dynamic>>? needStatistics;

  @HiveField(7)
  final String? aiSummary;

  @HiveField(8)
  final List<String>? referencedRecords;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  WeeklyInsightModel({
    required this.id,
    required this.weekRange,
    required this.startDate,
    required this.endDate,
    required this.emotionalPatterns,
    required this.microExperiments,
    this.needStatistics,
    this.aiSummary,
    this.referencedRecords,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 Domain 实体转换
  factory WeeklyInsightModel.fromEntity(WeeklyInsight entity) {
    return WeeklyInsightModel(
      id: entity.id,
      weekRange: entity.weekRange,
      startDate: entity.startDate,
      endDate: entity.endDate,
      emotionalPatterns:
          entity.emotionalPatterns.map((p) => p.toJson()).toList(),
      microExperiments:
          entity.microExperiments.map((e) => e.toJson()).toList(),
      needStatistics:
          entity.needStatistics?.map((s) => s.toJson()).toList(),
      aiSummary: entity.aiSummary,
      referencedRecords: entity.referencedRecords,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// 转换为 Domain 实体
  WeeklyInsight toEntity() {
    return WeeklyInsight(
      id: id,
      weekRange: weekRange,
      startDate: startDate,
      endDate: endDate,
      emotionalPatterns: emotionalPatterns
          .map((p) => EmotionalPattern.fromJson(p))
          .toList(),
      microExperiments: microExperiments
          .map((e) => MicroExperiment.fromJson(e))
          .toList(),
      needStatistics: needStatistics
          ?.map((s) => NeedStatistics.fromJson(s))
          .toList(),
      aiSummary: aiSummary,
      referencedRecords: referencedRecords,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
