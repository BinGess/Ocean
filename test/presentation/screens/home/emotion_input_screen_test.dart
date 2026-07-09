import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ai_auth_service.dart';
import 'package:mindflow/core/services/daily_summary_service.dart';
import 'package:mindflow/domain/entities/daily_summary.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/domain/repositories/ai_repository.dart';
import 'package:mindflow/domain/repositories/audio_repository.dart';
import 'package:mindflow/domain/repositories/record_repository.dart';
import 'package:mindflow/domain/usecases/create_quick_note_usecase.dart';
import 'package:mindflow/domain/usecases/get_records_usecase.dart';
import 'package:mindflow/domain/usecases/update_record_usecase.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/bloc/audio/audio_bloc.dart';
import 'package:mindflow/presentation/bloc/record/record_bloc.dart';
import 'package:mindflow/presentation/screens/home/emotion_input_screen.dart';

void main() {
  testWidgets('header keeps date control as icon-only action', (tester) async {
    final audioBloc = AudioBloc(audioRepository: _FakeAudioRepository());
    final repository = _FakeRecordRepository();
    final aiRepository = _FakeAIRepository();
    final recordBloc = RecordBloc(
      createQuickNoteUseCase: CreateQuickNoteUseCase(
        recordRepository: repository,
        aiRepository: aiRepository,
      ),
      getRecordsUseCase: GetRecordsUseCase(recordRepository: repository),
      updateRecordUseCase: UpdateRecordUseCase(recordRepository: repository),
      recordRepository: repository,
      aiRepository: aiRepository,
      aiAuthService: _FakeAIAuthService(),
      dailySummaryService: _FakeDailySummaryService(),
    );

    addTearDown(() async {
      await audioBloc.close();
      await recordBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AudioBloc>.value(value: audioBloc),
            BlocProvider<RecordBloc>.value(value: recordBloc),
          ],
          child: const EmotionInputScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+月\d+日·')), findsNothing);
  });

  testWidgets('NVC confirmation completion saves record and exits input screen',
      (tester) async {
    final audioBloc = AudioBloc(audioRepository: _FakeAudioRepository());
    final repository = _FakeRecordRepository();
    final aiRepository = _FakeAIRepository();
    final recordBloc = RecordBloc(
      createQuickNoteUseCase: CreateQuickNoteUseCase(
        recordRepository: repository,
        aiRepository: aiRepository,
      ),
      getRecordsUseCase: GetRecordsUseCase(recordRepository: repository),
      updateRecordUseCase: UpdateRecordUseCase(recordRepository: repository),
      recordRepository: repository,
      aiRepository: aiRepository,
      aiAuthService: _FakeAIAuthService(),
      dailySummaryService: _FakeDailySummaryService(),
    );

    addTearDown(() async {
      await audioBloc.close();
      await recordBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AudioBloc>.value(value: audioBloc),
            BlocProvider<RecordBloc>.value(value: recordBloc),
          ],
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider<AudioBloc>.value(value: audioBloc),
                          BlocProvider<RecordBloc>.value(value: recordBloc),
                        ],
                        child: const EmotionInputScreen(),
                      ),
                    ),
                  );
                },
                child: const Text('open input'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open input'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '今天发布流程卡住了');
    await tester.tap(find.text('NVC分析'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('行动 Tips'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('nvc-confirm-complete-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.createdRecords, hasLength(1));
    expect(repository.createdRecords.single.processingMode,
        ProcessingMode.withNVC);
    expect(repository.createdRecords.single.nvc?.observation, '今天发布流程卡住了');
    expect(find.text('open input'), findsOneWidget);
    expect(find.byType(EmotionInputScreen), findsNothing);
  });
}

class _FakeAudioRepository extends Fake implements AudioRepository {}

class _FakeRecordRepository extends Fake implements RecordRepository {
  final List<Record> createdRecords = [];

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
  }) async {
    final record = Record(
      id: 'record-${createdRecords.length + 1}',
      type: RecordType.quickNote,
      transcription: transcription,
      createdAt: createdAt ?? DateTime(2026, 5, 24),
      updatedAt: createdAt ?? DateTime(2026, 5, 24),
      audioUrl: audioUrl,
      duration: duration,
      processingMode: processingMode,
      moods: moods,
      needs: needs,
      nvc: nvc,
      deepAnalyses: deepAnalyses,
    );
    createdRecords.add(record);
    return record;
  }

  @override
  Future<List<Record>> getRecordsByDate(DateTime date) async {
    return createdRecords
        .where((record) =>
            record.createdAt.year == date.year &&
            record.createdAt.month == date.month &&
            record.createdAt.day == date.day)
        .toList();
  }

  @override
  Future<List<Record>> getAllRecords() async => createdRecords;
}

class _FakeAIRepository extends Fake implements AIRepository {
  @override
  bool isConfigured() => true;

  @override
  Future<NVCAnalysis> analyzeWithNVC(String transcription) async {
    return NVCAnalysis(
      observation: transcription,
      feelings: const [
        Feeling(feeling: '焦虑', intensity: IntensityLevel.high),
      ],
      needs: const [
        Need(need: '支持', reason: '希望流程可以稳定保存'),
      ],
      request: '先确认保存能完成',
      insight: '你正在把问题拆成可验证的步骤。',
      analyzedAt: DateTime(2026, 5, 24, 10),
    );
  }
}

class _FakeAIAuthService extends Fake implements AIAuthService {
  @override
  Future<bool> get isAuthorized async => true;
}

class _FakeDailySummaryService extends Fake implements DailySummaryService {
  @override
  Future<void> deleteDailySummary(DateTime date) async {}

  @override
  bool needsRegeneration(DateTime date, int currentRecordCount) => false;

  @override
  Future<DailySummary?> generateDailySummary(
    DateTime date,
    List<Record> records, {
    bool force = false,
  }) async {
    return null;
  }
}
