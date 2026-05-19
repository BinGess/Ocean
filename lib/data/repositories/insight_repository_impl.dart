/// 洞察仓储实现
/// 使用 Hive 进行本地存储
library;

import 'dart:convert';
import '../../core/network/ocean_api_client.dart';
import '../../core/services/ocean_record_ownership_service.dart';
import '../../domain/entities/weekly_insight.dart';
import '../../domain/entities/insight_report.dart';
import '../../domain/entities/insight_report_cache.dart';
import '../../domain/repositories/insight_repository.dart';
import '../datasources/local/hive_database.dart';
import '../models/weekly_insight_model.dart';

class InsightRepositoryImpl implements InsightRepository {
  final HiveDatabase database;
  final OceanUserDataApi? userDataApi;
  final OceanAccountApi? accountApi;
  final OceanRecordOwnershipService? ownershipService;

  InsightRepositoryImpl({
    required this.database,
    this.userDataApi,
    OceanAccountApi? accountApi,
    this.ownershipService,
  }) : accountApi = accountApi ??
            (userDataApi is OceanAccountApi
                ? userDataApi as OceanAccountApi
                : null);

  @override
  Future<WeeklyInsight> createWeeklyInsight(WeeklyInsight insight) async {
    final model = WeeklyInsightModel.fromEntity(insight);
    await database.weeklyInsightsBox.put(insight.id, model);
    await _markCurrentOwnerOrLocal('weekly_insight', insight.id);
    return model.toEntity();
  }

  @override
  Future<WeeklyInsight?> getWeeklyInsight(String weekRange) async {
    final model = database.weeklyInsightsBox.values
        .where((m) =>
            m.weekRange == weekRange && _isVisible('weekly_insight', m.id))
        .firstOrNull;
    return model?.toEntity();
  }

  @override
  Future<List<WeeklyInsight>> getAllWeeklyInsights() async {
    final models = database.weeklyInsightsBox.values
        .where((model) => _isVisible('weekly_insight', model.id))
        .toList();
    // 按创建时间降序排序
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<WeeklyInsight>> getRecentInsights({int limit = 4}) async {
    final models = database.weeklyInsightsBox.values
        .where((model) => _isVisible('weekly_insight', model.id))
        .toList();
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limitedModels = models.take(limit).toList();
    return limitedModels.map((m) => m.toEntity()).toList();
  }

  @override
  Future<WeeklyInsight> updateWeeklyInsight(WeeklyInsight insight) async {
    final model = WeeklyInsightModel.fromEntity(insight);
    await database.weeklyInsightsBox.put(insight.id, model);
    await _markCurrentOwnerOrLocal('weekly_insight', insight.id);
    return model.toEntity();
  }

  @override
  Future<void> deleteWeeklyInsight(String id) async {
    await database.weeklyInsightsBox.delete(id);
    await ownershipService?.clearEntityOwner('weekly_insight', id);
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

    final startStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final endStr =
        '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

    return '$startStr ~ $endStr';
  }

  @override
  Future<bool> hasInsightForWeek(String weekRange) async {
    final insight = await getWeeklyInsight(weekRange);
    return insight != null;
  }

  @override
  Future<InsightReportCache?> getCachedInsightReport(String weekRange) async {
    if (!_isVisible('insight_report', weekRange)) return null;
    final raw = database.insightReportsBox.get(weekRange);
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAtStr = data['cached_at'] as String?;
      final rawReport = data['report'];
      if (cachedAtStr == null || rawReport == null) return null;

      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt == null) return null;

      final report = _parseCachedInsightReport(rawReport, cachedAt: cachedAt);
      if (report == null) return null;
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
    final resolvedCachedAt = cachedAt ?? DateTime.now();
    final clientUpdatedAt = DateTime.now().toUtc().toIso8601String();
    final api = userDataApi;
    if (api != null && await api.isSignedIn) {
      await api.upsertReport(
        periodType: 'weekly',
        periodKey: report.weekRange,
        report: {
          'weekRange': report.weekRange,
          'cachedAt': resolvedCachedAt.toUtc().toIso8601String(),
          'recordCount': report.recordCount,
          'report': report.toJson(),
          'clientUpdatedAt': clientUpdatedAt,
        },
      );
      await _markCurrentOwnerOrLocal('insight_report', report.weekRange);
    } else {
      await ownershipService?.markEntityLocal(
          'insight_report', report.weekRange);
    }
    final payload = {
      'cached_at': resolvedCachedAt.toIso8601String(),
      'report': report.toJson(),
    };
    await database.insightReportsBox.put(report.weekRange, jsonEncode(payload));
  }

  @override
  Future<void> deleteInsightReportCache(String weekRange) async {
    await database.insightReportsBox.delete(weekRange);
    await ownershipService?.clearEntityOwner('insight_report', weekRange);
  }

  @override
  Future<List<InsightReportCache>> getAllCachedInsightReports() async {
    final List<InsightReportCache> results = [];
    for (final rawKey in database.insightReportsBox.keys) {
      final weekRange = rawKey.toString();
      if (!_isVisible('insight_report', weekRange)) continue;
      final raw = database.insightReportsBox.get(rawKey);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final cachedAtStr = data['cached_at'] as String?;
        final rawReport = data['report'];
        if (cachedAtStr == null || rawReport == null) continue;

        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt == null) continue;

        final report = _parseCachedInsightReport(rawReport, cachedAt: cachedAt);
        if (report == null) continue;
        results.add(InsightReportCache(report: report, cachedAt: cachedAt));
      } catch (_) {
        // 忽略解析失败的缓存
      }
    }

    results.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    return results;
  }

  bool _isVisible(String entityType, String entityId) {
    final ownership = ownershipService;
    if (ownership == null) return true;
    return ownership.isEntityVisible(
      entityType: entityType,
      entityId: entityId,
      accountKey: ownership.activeAccount,
    );
  }

  Future<void> _markCurrentOwnerOrLocal(
    String entityType,
    String entityId,
  ) async {
    final ownership = ownershipService;
    if (ownership == null) return;
    final api = accountApi;
    if (api != null && await api.isSignedIn) {
      final accountKey = await api.currentAccountKey;
      if (accountKey != null && accountKey.isNotEmpty) {
        await ownership.markEntityAccount(entityType, entityId, accountKey);
        return;
      }
    }
    await ownership.markEntityLocal(entityType, entityId);
  }

  InsightReport? _parseCachedInsightReport(
    Object rawReport, {
    required DateTime cachedAt,
  }) {
    try {
      final reportJson = _asMap(rawReport);
      if (reportJson == null) return null;
      return InsightReport.fromJson(
        _normalizeInsightReportJson(reportJson, cachedAt: cachedAt),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeInsightReportJson(
    Map<String, dynamic> json, {
    required DateTime cachedAt,
  }) {
    final weekRange =
        _readString(json, const ['week_range', 'weekRange']) ?? '';
    final pattern = _asMap(_read(json, const [
          'pattern_hypothesis',
          'patternHypothesis',
        ])) ??
        const <String, dynamic>{};

    return {
      ...json,
      'id': _readString(json, const ['id']) ??
          'report_${weekRange.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_')}',
      'report_type':
          _readString(json, const ['report_type', 'reportType']) ?? '每周洞察报告',
      'emotion_overview': _asMap(_read(json, const [
            'emotion_overview',
            'emotionOverview',
          ])) ??
          const {'summary': ''},
      'high_frequency_emotions': _readList(json, const [
        'high_frequency_emotions',
        'highFrequencyEmotions',
      ]),
      'pattern_hypothesis': {
        ...pattern,
        'text': _readString(pattern, const ['text']) ?? '',
        'highlight_tags': _readList(pattern, const [
          'highlight_tags',
          'highlightTags',
        ]),
      },
      'action_suggestions': _readList(json, const [
        'action_suggestions',
        'actionSuggestions',
      ]),
      'week_range': weekRange,
      'created_at': _readString(json, const ['created_at', 'createdAt']) ??
          cachedAt.toIso8601String(),
      'record_count': _read(json, const ['record_count', 'recordCount']),
    };
  }

  Object? _read(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    return null;
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    final value = _read(json, keys);
    return value?.toString();
  }

  List<dynamic> _readList(Map<String, dynamic> json, List<String> keys) {
    final value = _read(json, keys);
    if (value is List) return value;
    return const [];
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }
}
