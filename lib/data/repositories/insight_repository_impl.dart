/// 洞察仓储实现
/// 使用 Hive 进行本地存储

import 'dart:convert';
import '../../domain/entities/weekly_insight.dart';
import '../../domain/entities/insight_report.dart';
import '../../domain/entities/insight_report_cache.dart';
import '../../domain/repositories/insight_repository.dart';
import '../datasources/local/hive_database.dart';
import '../models/weekly_insight_model.dart';

class InsightRepositoryImpl implements InsightRepository {
  final HiveDatabase database;

  InsightRepositoryImpl({required this.database});

  @override
  Future<WeeklyInsight> createWeeklyInsight(WeeklyInsight insight) async {
    final model = WeeklyInsightModel.fromEntity(insight);
    await database.weeklyInsightsBox.put(insight.id, model);
    return model.toEntity();
  }

  @override
  Future<WeeklyInsight?> getWeeklyInsight(String weekRange) async {
    final model = database.weeklyInsightsBox.values
        .where((m) => m.weekRange == weekRange)
        .firstOrNull;
    return model?.toEntity();
  }

  @override
  Future<List<WeeklyInsight>> getAllWeeklyInsights() async {
    final models = database.weeklyInsightsBox.values.toList();
    // 按创建时间降序排序
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<WeeklyInsight>> getRecentInsights({int limit = 4}) async {
    final models = database.weeklyInsightsBox.values.toList();
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limitedModels = models.take(limit).toList();
    return limitedModels.map((m) => m.toEntity()).toList();
  }

  @override
  Future<WeeklyInsight> updateWeeklyInsight(WeeklyInsight insight) async {
    final model = WeeklyInsightModel.fromEntity(insight);
    await database.weeklyInsightsBox.put(insight.id, model);
    return model.toEntity();
  }

  @override
  Future<void> deleteWeeklyInsight(String id) async {
    await database.weeklyInsightsBox.delete(id);
  }

  @override
  Future<void> updatePatternFeedback(
    String insightId,
    String patternId,
    String feedback,
  ) async {
    // TODO: 实现情绪模式反馈更新逻辑
  }

  @override
  Future<void> updateExperimentStatus(
    String insightId,
    String experimentId,
    String status,
  ) async {
    // TODO: 实现微实验状态更新逻辑
  }

  @override
  Future<void> updateExperimentFeedback(
    String insightId,
    String experimentId,
    String feedback,
  ) async {
    // TODO: 实现微实验反馈更新逻辑
  }

  @override
  String getCurrentWeekRange() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final startStr = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final endStr = '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

    return '$startStr ~ $endStr';
  }

  @override
  Future<bool> hasInsightForWeek(String weekRange) async {
    final insight = await getWeeklyInsight(weekRange);
    return insight != null;
  }

  @override
  Future<InsightReportCache?> getCachedInsightReport(String weekRange) async {
    final raw = database.insightReportsBox.get(weekRange);
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAtStr = data['cached_at'] as String?;
      final reportJson = data['report'] as Map<String, dynamic>?;
      if (cachedAtStr == null || reportJson == null) return null;

      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt == null) return null;

      final report = InsightReport.fromJson(reportJson);
      return InsightReportCache(report: report, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveInsightReportCache(
    InsightReport report, {
    DateTime? cachedAt,
  }) async {
    final payload = {
      'cached_at': (cachedAt ?? DateTime.now()).toIso8601String(),
      'report': report.toJson(),
    };
    await database.insightReportsBox.put(report.weekRange, jsonEncode(payload));
  }

  @override
  Future<void> deleteInsightReportCache(String weekRange) async {
    await database.insightReportsBox.delete(weekRange);
  }

  @override
  Future<List<InsightReportCache>> getAllCachedInsightReports() async {
    final List<InsightReportCache> results = [];
    for (final raw in database.insightReportsBox.values) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final cachedAtStr = data['cached_at'] as String?;
        final reportJson = data['report'] as Map<String, dynamic>?;
        if (cachedAtStr == null || reportJson == null) continue;

        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt == null) continue;

        final report = InsightReport.fromJson(reportJson);
        results.add(InsightReportCache(report: report, cachedAt: cachedAt));
      } catch (_) {
        // 忽略解析失败的缓存
      }
    }

    results.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    return results;
  }
}
