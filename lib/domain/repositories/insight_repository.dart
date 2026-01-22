/// 洞察仓储接口（Repository Interface）
/// 定义周洞察相关的数据访问契约

import '../entities/weekly_insight.dart';

abstract class InsightRepository {
  /// 创建周洞察
  Future<WeeklyInsight> createWeeklyInsight(WeeklyInsight insight);

  /// 获取指定周的洞察
  /// [weekRange] 周范围（例如："2025-01-13 ~ 2025-01-19"）
  Future<WeeklyInsight?> getWeeklyInsight(String weekRange);

  /// 获取所有周洞察
  Future<List<WeeklyInsight>> getAllWeeklyInsights();

  /// 获取最近的周洞察
  Future<List<WeeklyInsight>> getRecentInsights({int limit = 4});

  /// 更新周洞察
  Future<WeeklyInsight> updateWeeklyInsight(WeeklyInsight insight);

  /// 删除周洞察
  Future<void> deleteWeeklyInsight(String id);

  /// 更新情绪模式反馈
  Future<void> updatePatternFeedback(
    String insightId,
    String patternId,
    String feedback,
  );

  /// 更新微实验状态
  Future<void> updateExperimentStatus(
    String insightId,
    String experimentId,
    String status,
  );

  /// 更新微实验反馈
  Future<void> updateExperimentFeedback(
    String insightId,
    String experimentId,
    String feedback,
  );

  /// 获取当前周的周范围
  String getCurrentWeekRange();

  /// 检查指定周是否已有洞察
  Future<bool> hasInsightForWeek(String weekRange);
}
