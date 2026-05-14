import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ai_auth_service.dart';
import 'package:mindflow/core/services/daily_summary_service.dart';
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
}

class _FakeAudioRepository extends Fake implements AudioRepository {}

class _FakeRecordRepository extends Fake implements RecordRepository {}

class _FakeAIRepository extends Fake implements AIRepository {
  @override
  bool isConfigured() => true;
}

class _FakeAIAuthService extends Fake implements AIAuthService {}

class _FakeDailySummaryService extends Fake implements DailySummaryService {}
