import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ai_auth_service.dart';
import 'package:mindflow/core/services/daily_summary_service.dart';
import 'package:mindflow/domain/entities/daily_summary.dart';
import 'package:mindflow/domain/entities/insight_report.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/domain/entities/weekly_insight.dart';
import 'package:mindflow/domain/repositories/ai_repository.dart';
import 'package:mindflow/domain/repositories/record_repository.dart';
import 'package:mindflow/domain/usecases/create_quick_note_usecase.dart';
import 'package:mindflow/domain/usecases/get_records_usecase.dart';
import 'package:mindflow/domain/usecases/update_record_usecase.dart';
import 'package:mindflow/presentation/bloc/record/record_bloc.dart';
import 'package:mindflow/presentation/bloc/record/record_event.dart';

void main() {
  test(
    'saving the second local-day record generates daily summary even when createdAt is UTC',
    () async {
      final firstRecord = Record(
        id: 'server-record-1',
        type: RecordType.quickNote,
        transcription: '凌晨的第一条记录',
        createdAt: DateTime.utc(2026, 5, 17, 17),
        updatedAt: DateTime.utc(2026, 5, 17, 17),
      );
      final secondRecord = Record(
        id: 'server-record-2',
        type: RecordType.quickNote,
        transcription: '凌晨的第二条记录',
        createdAt: DateTime.utc(2026, 5, 17, 17, 10),
        updatedAt: DateTime.utc(2026, 5, 17, 17, 10),
      );
      final repository = _FakeRecordRepository(
        initialRecords: [firstRecord],
        nextCreatedRecord: secondRecord,
      );
      final dailySummaryService = _FakeDailySummaryService();
      final bloc = RecordBloc(
        createQuickNoteUseCase: CreateQuickNoteUseCase(
          recordRepository: repository,
          aiRepository: _FakeAIRepository(),
        ),
        getRecordsUseCase: GetRecordsUseCase(recordRepository: repository),
        updateRecordUseCase: UpdateRecordUseCase(recordRepository: repository),
        recordRepository: repository,
        aiRepository: _FakeAIRepository(),
        aiAuthService: _FakeAIAuthService(),
        dailySummaryService: dailySummaryService,
      );

      addTearDown(bloc.close);

      bloc.add(
        const RecordCreateQuickNote(
          mode: ProcessingMode.onlyRecord,
          transcription: '凌晨的第二条记录',
        ),
      );

      await dailySummaryService.generated;

      expect(dailySummaryService.generatedRecords.single.length, 2);
      expect(dailySummaryService.generatedDates.single,
          DateTime.utc(2026, 5, 17, 17, 10).toLocalDay());
    },
  );
}

extension on DateTime {
  DateTime toLocalDay() {
    final local = toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class _FakeDailySummaryService extends Fake implements DailySummaryService {
  final Completer<void> _generated = Completer<void>();
  final List<DateTime> generatedDates = [];
  final List<List<Record>> generatedRecords = [];

  Future<void> get generated => _generated.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw StateError('Daily summary was not generated'),
      );

  @override
  bool needsRegeneration(DateTime date, int currentRecordCount) {
    return currentRecordCount >= DailySummaryService.minRecordCount;
  }

  @override
  Future<void> deleteDailySummary(DateTime date) async {}

  @override
  Future<DailySummary?> generateDailySummary(
    DateTime date,
    List<Record> records, {
    bool force = false,
  }) async {
    generatedDates.add(date);
    generatedRecords.add(records);
    if (!_generated.isCompleted) {
      _generated.complete();
    }
    return DailySummary(
      date: date,
      moodWord: '平静',
      oneSentence: '今天有两条记录。',
      score: 80,
      recordCount: records.length,
      generatedAt: DateTime(2026, 5, 18, 1, 15),
    );
  }
}

class _FakeRecordRepository extends Fake implements RecordRepository {
  _FakeRecordRepository({
    required List<Record> initialRecords,
    required this.nextCreatedRecord,
  }) : _records = [...initialRecords];

  final List<Record> _records;
  final Record nextCreatedRecord;

  @override
  Future<Record> createQuickNote({
    required String transcription,
    String? audioUrl,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,
    DateTime? createdAt,
  }) async {
    _records.add(nextCreatedRecord);
    return nextCreatedRecord;
  }

  @override
  Future<List<Record>> getAllRecords() async {
    return [..._records]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Record>> getRecordsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _records
        .where((record) =>
            !record.createdAt.isBefore(startOfDay) &&
            record.createdAt.isBefore(endOfDay))
        .toList();
  }

  @override
  Future<Record?> getRecordById(String id) async {
    return _records.where((record) => record.id == id).firstOrNull;
  }
}

class _FakeAIRepository extends Fake implements AIRepository {
  @override
  bool isConfigured() => true;

  @override
  Future<List<EmotionalPattern>> analyzeEmotionalPatterns(
          List<String> recordIds) =>
      throw UnimplementedError();

  @override
  Future<String> generateJournalSummary(String transcription) =>
      throw UnimplementedError();

  @override
  Future<String> generateJournalTitle(String transcription) =>
      throw UnimplementedError();

  @override
  Future<WeeklyInsight> generateWeeklyInsight(List<String> recordIds) =>
      throw UnimplementedError();

  @override
  Future<List<String>> identifyNeeds(String emotions) async => const [];

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) =>
      throw UnimplementedError();

  @override
  Future<String> transcribeAudioFile(String audioPath) =>
      throw UnimplementedError();
}

class _FakeAIAuthService extends Fake implements AIAuthService {
  @override
  Future<bool> get isAuthorized async => true;
}
