import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/day_aggregation.dart';
import 'package:mindflow/domain/entities/daily_summary.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/domain/entities/insight_report.dart';
import 'package:mindflow/domain/entities/insight_report_cache.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/domain/entities/weekly_analysis.dart';
import 'package:mindflow/domain/entities/weekly_insight.dart';
import 'package:mindflow/domain/repositories/insight_repository.dart';
import 'package:mindflow/domain/repositories/record_repository.dart';
import 'package:mindflow/domain/usecases/build_weekly_analysis_usecase.dart';
import 'package:mindflow/domain/usecases/get_weekly_insights_usecase.dart';
import 'package:mindflow/presentation/bloc/insight/insight_bloc.dart';
import 'package:mindflow/presentation/bloc/insight/insight_event.dart';
import 'package:mindflow/presentation/bloc/insight/insight_state.dart';

void main() {
  test('uses local weekly analysis when server returns an empty overview',
      () async {
    final insightRepository = _FakeInsightRepository(
      serverAnalysis: _analysis(totalRecords: 0),
    );
    final recordRepository = _FakeRecordRepository([
      _record(id: 'record-1', createdAt: DateTime.now()),
      _record(id: 'record-2', createdAt: DateTime.now()),
      _record(id: 'record-3', createdAt: DateTime.now()),
    ]);
    final bloc = InsightBloc(
      getWeeklyInsightsUseCase:
          GetWeeklyInsightsUseCase(insightRepository: insightRepository),
      buildWeeklyAnalysisUseCase:
          BuildWeeklyAnalysisUseCase(recordRepository: recordRepository),
      insightRepository: insightRepository,
    );
    addTearDown(bloc.close);

    bloc.add(const InsightLoadCurrentWeek());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state.status, InsightStatus.success);
    expect(bloc.state.weeklyAnalysis?.totalRecords, 3);
  });
}

Record _record({
  required String id,
  required DateTime createdAt,
}) {
  return Record(
    id: id,
    type: RecordType.quickNote,
    transcription: '今天记录了一点状态',
    createdAt: createdAt,
    updatedAt: createdAt,
    moods: const ['平静'],
    needs: const ['休息'],
  );
}

WeeklyAnalysis _analysis({required int totalRecords}) {
  return WeeklyAnalysis(
    weekRange: 'server-week',
    totalRecords: totalRecords,
    activeDays: 0,
    longestStreak: 0,
    topMood: null,
    topNeed: null,
    topMoods: const [],
    topNeeds: const [],
    peakTimeBucket: null,
    busiestWeekday: null,
    moodTaggedCount: 0,
    needTaggedCount: 0,
    coverageSummary: '0/0 条记录包含心情，0/0 条记录包含需求',
    changesSummary: const [],
  );
}

class _FakeInsightRepository implements InsightRepository {
  _FakeInsightRepository({this.serverAnalysis});

  final WeeklyAnalysis? serverAnalysis;

  @override
  Future<WeeklyAnalysis?> fetchServerWeeklyAnalysis({
    required String startDate,
    required String endDate,
  }) async {
    return serverAnalysis;
  }

  @override
  Future<InsightReportCache?> getCachedInsightReport(String weekRange) async {
    return null;
  }

  @override
  Future<List<WeeklyInsight>> getAllWeeklyInsights() async => const [];

  @override
  Future<List<WeeklyInsight>> getRecentInsights({int limit = 4}) async =>
      const [];

  @override
  Future<WeeklyInsight> createWeeklyInsight(WeeklyInsight insight) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteInsightReportCache(String weekRange) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWeeklyInsight(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<InsightReportCache>> getAllCachedInsightReports() {
    throw UnimplementedError();
  }

  @override
  String getCurrentWeekRange() {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyInsight?> getWeeklyInsight(String weekRange) {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasInsightForWeek(String weekRange) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveInsightReportCache(
    InsightReport report, {
    DateTime? cachedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyInsight> updateWeeklyInsight(WeeklyInsight insight) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateExperimentFeedback(
    String insightId,
    String experimentId,
    String feedback,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateExperimentStatus(
    String insightId,
    String experimentId,
    String status,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePatternFeedback(
    String insightId,
    String patternId,
    String feedback,
  ) {
    throw UnimplementedError();
  }
}

class _FakeRecordRepository implements RecordRepository {
  _FakeRecordRepository(this._records);

  final List<Record> _records;

  @override
  Future<List<Record>> getRecordsByDateRange(
      DateTime start, DateTime end) async {
    return _records
        .where((record) =>
            !record.createdAt.isBefore(start) && !record.createdAt.isAfter(end))
        .toList();
  }

  @override
  Future<Record> createQuickNote({
    required String transcription,
    String? audioUrl,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,
    List<DeepAnalysisResult>? deepAnalyses,
    DateTime? createdAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Record> createJournal({
    required String transcription,
    String? title,
    String? summary,
    List<String>? referencedFragments,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Record> createWeeklyRecord({
    required String transcription,
    required String weekRange,
    List<String>? referencedRecords,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecord(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<DayAggregation>> getDayAggregations(
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<DayAggregation?> getDayAggregation(String dayKey) {
    throw UnimplementedError();
  }

  @override
  Future<List<Record>> getAllRecords() {
    throw UnimplementedError();
  }

  @override
  Future<List<Record>> getRecordsByDate(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<List<Record>> getRecordsByType(RecordType type) {
    throw UnimplementedError();
  }

  @override
  Future<List<Record>> getRecentRecords({int limit = 10}) {
    throw UnimplementedError();
  }

  @override
  Future<Record?> getRecordById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Record>> searchRecords(String query) {
    throw UnimplementedError();
  }

  @override
  Future<Record> updateNVCAnalysis(String id, nvcAnalysis) {
    throw UnimplementedError();
  }

  @override
  Future<Record> updateProcessingMode(String id, ProcessingMode mode) {
    throw UnimplementedError();
  }

  @override
  Future<Record> updateRecord(Record record) {
    throw UnimplementedError();
  }
}
