import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ai_auth_service.dart';
import 'package:mindflow/core/services/daily_summary_service.dart';
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
import 'package:mindflow/presentation/screens/record_detail/record_detail_screen.dart';
import 'package:mindflow/presentation/widgets/nvc_analyzing_modal.dart';

void main() {
  testWidgets('NVC action on text detail opens animated analyzing modal',
      (tester) async {
    final repository = _FakeRecordRepository();
    final aiRepository = _PendingAIRepository();
    final bloc = RecordBloc(
      createQuickNoteUseCase: CreateQuickNoteUseCase(
        recordRepository: repository,
        aiRepository: aiRepository,
      ),
      getRecordsUseCase: GetRecordsUseCase(recordRepository: repository),
      updateRecordUseCase: UpdateRecordUseCase(recordRepository: repository),
      recordRepository: repository,
      aiRepository: aiRepository,
      aiAuthService: _AuthorizedAIAuthService(),
      dailySummaryService: _FakeDailySummaryService(),
    );

    addTearDown(() async {
      aiRepository.complete();
      await bloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RecordBloc>.value(
          value: bloc,
          child: RecordDetailScreen(
            record: Record(
              id: 'text-record',
              type: RecordType.quickNote,
              transcription: '今天只是保存了一段纯文本。',
              createdAt: DateTime(2026, 3, 22, 10, 30),
              updatedAt: DateTime(2026, 3, 22, 10, 30),
              processingMode: ProcessingMode.onlyRecord,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('让AI来分析你的情况'));
    await tester.pump();

    expect(find.byType(NVCAnalyzingModal), findsOneWidget);

    aiRepository.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _AuthorizedAIAuthService extends Fake implements AIAuthService {
  @override
  Future<bool> get isAuthorized async => true;
}

class _FakeDailySummaryService extends Fake implements DailySummaryService {}

class _FakeRecordRepository extends Fake implements RecordRepository {}

class _PendingAIRepository extends Fake implements AIRepository {
  final Completer<NVCAnalysis> _completer = Completer<NVCAnalysis>();

  void complete() {
    if (_completer.isCompleted) return;
    _completer.complete(
      NVCAnalysis(
        observation: '记录了一段文本',
        feelings: const [
          Feeling(feeling: '平静', intensity: IntensityLevel.medium),
        ],
        needs: const [
          Need(need: '表达', reason: '希望整理想法'),
        ],
        request: '继续观察自己的感受',
        analyzedAt: DateTime(2026, 3, 22, 10, 31),
      ),
    );
  }

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) {
    return _completer.future;
  }

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
  Future<InsightReport> generateInsightReport(
          List<InsightRequestRecord> records, String weekRange) =>
      throw UnimplementedError();

  @override
  Future<List<MicroExperiment>> generateMicroExperiments(
          List<String> dominantNeeds) =>
      throw UnimplementedError();

  @override
  Future<WeeklyInsight> generateWeeklyInsight(List<String> recordIds) =>
      throw UnimplementedError();

  @override
  Future<List<String>> identifyMoods(String transcription) =>
      throw UnimplementedError();

  @override
  Future<List<String>> identifyNeeds(String transcription) =>
      throw UnimplementedError();

  @override
  Future<String> transcribeAudioFile(String audioPath) =>
      throw UnimplementedError();

  @override
  Future<String> transcribeAudioStream(Stream<List<int>> audioStream) =>
      throw UnimplementedError();
}
