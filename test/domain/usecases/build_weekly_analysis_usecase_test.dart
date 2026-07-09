import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/domain/entities/weekly_analysis.dart';
import 'package:mindflow/domain/entities/day_aggregation.dart';
import 'package:mindflow/domain/repositories/record_repository.dart';
import 'package:mindflow/domain/usecases/build_weekly_analysis_usecase.dart';

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
  Future<Record> createJournal({
    required String transcription,
    String? title,
    String? summary,
    List<String>? referencedFragments,
  }) {
    throw UnimplementedError();
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
  Future<List<Record>> getAllRecords() {
    throw UnimplementedError();
  }

  @override
  Future<DayAggregation?> getDayAggregation(String dayKey) {
    throw UnimplementedError();
  }

  @override
  Future<List<DayAggregation>> getDayAggregations(
      DateTime start, DateTime end) {
    throw UnimplementedError();
  }

  @override
  Future<Record?> getRecordById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Record>> getRecentRecords({int limit = 10}) {
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
  Future<List<Record>> searchRecords(String query) {
    throw UnimplementedError();
  }

  @override
  Future<Record> updateNVCAnalysis(String id, dynamic nvcAnalysis) {
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

Record _record({
  required String id,
  required DateTime createdAt,
  List<String>? moods,
  List<String>? needs,
  NVCAnalysis? nvc,
}) {
  return Record(
    id: id,
    type: RecordType.quickNote,
    transcription: 'record-$id',
    createdAt: createdAt,
    updatedAt: createdAt,
    moods: moods,
    needs: needs,
    nvc: nvc,
  );
}

NVCAnalysis _nvc({
  List<String> feelings = const [],
  List<String> needs = const [],
}) {
  return NVCAnalysis(
    observation: 'obs',
    feelings: feelings
        .map(
          (feeling) => const Feeling(
            feeling: '',
            intensity: IntensityLevel.medium,
          ),
        )
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => Feeling(
            feeling: feelings[entry.key],
            intensity: IntensityLevel.medium,
          ),
        )
        .toList(),
    needs:
        needs.map((need) => Need(need: need, reason: 'reason-$need')).toList(),
    analyzedAt: DateTime(2026, 3, 22, 8),
  );
}

void main() {
  group('BuildWeeklyAnalysisUseCase', () {
    test('builds weekly overview, distributions, and comparisons', () async {
      final startDate = DateTime(2026, 3, 16);
      final endDate = DateTime(2026, 3, 22, 23, 59, 59);
      final repository = _FakeRecordRepository([
        _record(
          id: '1',
          createdAt: DateTime(2026, 3, 16, 8, 30),
          moods: const ['焦虑', '期待'],
          needs: const ['支持'],
        ),
        _record(
          id: '2',
          createdAt: DateTime(2026, 3, 17, 21, 10),
          moods: const ['平静'],
          needs: const ['休息'],
        ),
        _record(
          id: '3',
          createdAt: DateTime(2026, 3, 18, 22, 20),
          moods: const ['焦虑'],
          needs: const ['支持'],
        ),
        _record(
          id: '4',
          createdAt: DateTime(2026, 3, 20, 14, 00),
          moods: const ['开心'],
          needs: const ['连接'],
        ),
        _record(
          id: '5',
          createdAt: DateTime(2026, 3, 21, 20, 15),
          moods: const ['焦虑'],
          needs: const ['支持'],
        ),
        _record(
          id: '6',
          createdAt: DateTime(2026, 3, 10, 20, 00),
          moods: const ['焦虑'],
          needs: const ['支持'],
        ),
        _record(
          id: '7',
          createdAt: DateTime(2026, 3, 11, 20, 00),
          moods: const ['平静'],
          needs: const ['休息'],
        ),
      ]);

      final useCase = BuildWeeklyAnalysisUseCase(recordRepository: repository);

      final analysis = await useCase(
        BuildWeeklyAnalysisParams(
          weekRange: '2026-03-16 ~ 2026-03-22',
          startDate: startDate,
          endDate: endDate,
        ),
      );

      expect(analysis.totalRecords, 5);
      expect(analysis.activeDays, 5);
      expect(analysis.longestStreak, 3);
      expect(analysis.topMood, '焦虑');
      expect(analysis.topNeed, '支持');
      expect(analysis.topMoods.first,
          const WeeklyTagStat(label: '焦虑', count: 3, percentage: 50));
      expect(analysis.topNeeds.first,
          const WeeklyTagStat(label: '支持', count: 3, percentage: 60));
      expect(analysis.peakTimeBucket, '晚上');
      expect(analysis.busiestWeekday, '周一');
      expect(analysis.moodTaggedCount, 5);
      expect(analysis.needTaggedCount, 5);
      expect(analysis.coverageSummary, '5/5 条记录包含心情，5/5 条记录包含需求');
      expect(analysis.changesSummary, contains('本周记录数较上周增加 3 条'));
      expect(analysis.changesSummary, contains('“焦虑”比上周多出现 2 次'));
      expect(analysis.changesSummary, contains('“支持”比上周多出现 2 次'));
    });

    test('falls back to nvc feelings and needs when direct tags are missing',
        () async {
      final repository = _FakeRecordRepository([
        _record(
          id: '1',
          createdAt: DateTime(2026, 3, 16, 23, 10),
          nvc: _nvc(feelings: const ['疲惫'], needs: const ['休息']),
        ),
      ]);

      final useCase = BuildWeeklyAnalysisUseCase(recordRepository: repository);

      final analysis = await useCase(
        BuildWeeklyAnalysisParams(
          weekRange: '2026-03-16 ~ 2026-03-22',
          startDate: DateTime(2026, 3, 16),
          endDate: DateTime(2026, 3, 22, 23, 59, 59),
        ),
      );

      expect(analysis.topMood, '疲惫');
      expect(analysis.topNeed, '休息');
      expect(analysis.peakTimeBucket, '深夜');
      expect(analysis.moodTaggedCount, 1);
      expect(analysis.needTaggedCount, 1);
    });
  });
}
