/// 洞察仓储实现
/// 使用 Hive 进行本地存储

import '../../domain/entities/weekly_insight.dart';
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
}
