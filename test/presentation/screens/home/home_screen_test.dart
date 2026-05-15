import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/quote_preloader.dart';
import 'package:mindflow/data/repositories/quotes_repository.dart';
import 'package:mindflow/domain/entities/quote.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/bloc/audio/audio_bloc.dart';
import 'package:mindflow/presentation/bloc/audio/audio_event.dart';
import 'package:mindflow/presentation/bloc/audio/audio_state.dart';
import 'package:mindflow/presentation/bloc/record/record_bloc.dart';
import 'package:mindflow/presentation/bloc/record/record_event.dart';
import 'package:mindflow/presentation/bloc/record/record_state.dart';
import 'package:mindflow/presentation/screens/home/home_screen.dart';
import 'package:mindflow/presentation/widgets/quote_card.dart';
import 'package:mindflow/presentation/widgets/quote_display.dart';

void main() {
  setUp(() {
    if (getIt.isRegistered<QuotePreloader>()) {
      getIt.unregister<QuotePreloader>();
    }
  });

  tearDown(() {
    if (getIt.isRegistered<QuotePreloader>()) {
      getIt.unregister<QuotePreloader>();
    }
  });

  testWidgets('home quote carousel follows the selected English locale',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    getIt.registerSingleton<QuotePreloader>(
      _FakeQuotePreloader([
        _quote(
          content: '先写一行，今天就不算白过。',
          contentEn: 'One line down - today already counts.',
        ),
      ]),
    );

    await tester.pumpWidget(
      _buildHomeTestable(locale: const Locale('en')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('One line down'), findsWidgets);
    expect(find.textContaining('先写一行'), findsNothing);
  });

  testWidgets('quote card follows the selected English locale', (tester) async {
    await tester.pumpWidget(
      _buildQuoteCardTestable(
        locale: const Locale('en'),
        quote: _quote(
          content: '观察当下，不做评判。',
          contentEn: 'Observe the moment without judgment.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Observe the moment without judgment.'), findsOneWidget);
    expect(find.text('观察当下，不做评判。'), findsNothing);
    expect(find.text('Mindfulness'), findsOneWidget);
    expect(find.text('Tap to switch'), findsOneWidget);
  });

  testWidgets('quote empty state follows the selected English locale',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: QuoteDisplay(quotes: []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No quote data yet'), findsOneWidget);
    expect(find.text('暂无文案数据'), findsNothing);
  });
}

Widget _buildHomeTestable({required Locale locale}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AudioBloc>.value(value: _FakeAudioBloc()),
        BlocProvider<RecordBloc>.value(value: _FakeRecordBloc()),
      ],
      child: const HomeScreen(),
    ),
  );
}

Widget _buildQuoteCardTestable({
  required Locale locale,
  required Quote quote,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: QuoteCard(
        quote: quote,
        onNext: () {},
      ),
    ),
  );
}

Quote _quote({
  required String content,
  required String contentEn,
}) {
  return Quote(
    id: 'test-quote',
    content: content,
    contentEn: contentEn,
    author: 'MindFlow',
    category: QuoteCategory.mindfulness,
    targetMoods: const [],
    timeContext: TimeContext.anytime,
    weight: 1,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

class _FakeQuotePreloader extends QuotePreloader {
  _FakeQuotePreloader(this._quotes)
      : super(quotesRepository: _FakeQuotesRepository());

  final List<Quote> _quotes;

  @override
  Future<void> preload() async {}

  @override
  List<Quote> getCachedQuotes() => _quotes;
}

class _FakeQuotesRepository extends Fake implements QuotesRepository {}

class _FakeAudioBloc extends Fake implements AudioBloc {
  @override
  AudioState get state => AudioState.initial().copyWith(hasPermission: true);

  @override
  Stream<AudioState> get stream => const Stream<AudioState>.empty();

  @override
  void add(AudioEvent event) {}

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
