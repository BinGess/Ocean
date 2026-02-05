import 'insight_report.dart';

/// 洞察报告缓存实体（用于持久化缓存）
class InsightReportCache {
  final InsightReport report;
  final DateTime cachedAt;

  const InsightReportCache({
    required this.report,
    required this.cachedAt,
  });
}

