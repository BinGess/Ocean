import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/ai_auth_service.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/bloc/insight/insight_bloc.dart';
import 'package:mindflow/presentation/bloc/insight/insight_event.dart';
import 'package:mindflow/presentation/bloc/insight/insight_state.dart';
import 'package:mindflow/presentation/bloc/record/record_bloc.dart';
import 'package:mindflow/presentation/bloc/record/record_event.dart';
import 'package:mindflow/presentation/bloc/record/record_state.dart';
import 'package:mindflow/presentation/screens/insights/insights_screen.dart';

void main() {
  setUp(() {
    if (getIt.isRegistered<AIAuthService>()) {
      getIt.unregister<AIAuthService>();
    }
    getIt.registerSingleton<AIAuthService>(_FakeAIAuthService());
  });

  tearDown(() {
    if (getIt.isRegistered<AIAuthService>()) {
      getIt.unregister<AIAuthService>();
    }
  });

  testWidgets('empty insights state keeps page and weekly report context',
      (tester) async {
    await tester.pumpWidget(
      _buildTestable(
        insightBloc: _FakeInsightBloc(
          InsightState.initial().copyWith(
            status: InsightStatus.success,
            currentWeekRange: '2026-05-11 ~ 2026-05-17',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('洞察'), findsOneWidget);
    expect(find.text('5月11日 - 5月17日'), findsOneWidget);
    expect(find.text('每周洞察报告'), findsOneWidget);
    expect(find.text('本周没有足够的内容生成洞察'), findsOneWidget);
  });
}

Widget _buildTestable({required InsightBloc insightBloc}) {
  return MaterialApp(
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
        BlocProvider<InsightBloc>.value(value: insightBloc),
        BlocProvider<RecordBloc>.value(value: _FakeRecordBloc()),
      ],
      child: const InsightsScreen(),
    ),
  );
}

class _FakeAIAuthService extends Fake implements AIAuthService {
  @override
  Stream<bool> get authStateStream => const Stream<bool>.empty();
}

class _FakeInsightBloc extends Fake implements InsightBloc {
  _FakeInsightBloc(this._state);

  final InsightState _state;

  @override
  InsightState get state => _state;

  @override
  Stream<InsightState> get stream => const Stream<InsightState>.empty();

  @override
  void add(InsightEvent event) {}

  @override
  Future<void> close() async {}
}

class _FakeRecordBloc extends Fake implements RecordBloc {
  @override
  RecordState get state => RecordState.initial();

  @override
  Stream<RecordState> get stream => const Stream<RecordState>.empty();

  @override
  void add(RecordEvent event) {}

  @override
  Future<void> close() async {}
}
