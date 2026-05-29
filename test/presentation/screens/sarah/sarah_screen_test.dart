import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_bloc.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_event.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_state.dart';
import 'package:mindflow/presentation/screens/sarah/sarah_screen.dart';

void main() {
  testWidgets('renders weekly and past Sarah letters', (tester) async {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thisSunday = thisMonday.add(const Duration(days: 6));
    final bloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'weekly',
            type: LetterType.weekly,
            createdAt: now,
            weekStart: thisMonday,
            weekEnd: thisSunday,
            content: '嗨，\n\n你周三写到杭州旅行的记录，我读了好几遍。\n\nSarah',
            isRead: false,
          ),
          _letter(
            id: 'legacy',
            type: LetterType.legacy,
            createdAt: DateTime(2026, 5, 4),
            previewText: '那个关于截止日前夜的记录，让我想...',
            content: '嗨，\n\n那个关于截止日前夜的记录，让我想起你当时很需要支持。\n\nSarah',
            isRead: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(bloc));
    await tester.pump();

    expect(find.text('From Sarah'), findsOneWidget);
    expect(find.text('Stay with you'), findsOneWidget);
    expect(find.text('共 2 封信'), findsOneWidget);
    expect(find.text('本周来信'), findsOneWidget);
    expect(find.text('往期信件'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('sarah-unread-dot-weekly')), findsOneWidget);
  });

  testWidgets('expanding a letter dispatches read event', (tester) async {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thisSunday = thisMonday.add(const Duration(days: 6));
    final bloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'weekly',
            type: LetterType.weekly,
            createdAt: now,
            weekStart: thisMonday,
            weekEnd: thisSunday,
            content: '嗨，\n\n你周三写到杭州旅行的记录，我读了好几遍。\n\nSarah',
            isRead: false,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(bloc));
    await tester.pump();
    await tester.pump();

    expect(bloc.events.whereType<SarahLetterRead>().single.letterId, 'weekly');
  });

  testWidgets('fits a compact mobile viewport without layout exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'weekly',
            type: LetterType.weekly,
            createdAt: DateTime(2026, 5, 24),
            content:
                '嗨，\n\n你周三写到杭州旅行的记录，我读了好几遍。那句难得的亲情时光很亮，也很轻，像是在一周里留下一个可以慢慢回去的地方。\n\nSarah',
            isRead: false,
          ),
          _letter(
            id: 'legacy',
            type: LetterType.legacy,
            createdAt: DateTime(2026, 5, 4),
            previewText: '那个关于截止日前夜的记录，让我想...',
            content: '嗨，\n\n那个关于截止日前夜的记录，让我想起你当时很需要支持。\n\nSarah',
            isRead: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(bloc));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('From Sarah'), findsOneWidget);
    expect(find.text('共 2 封信'), findsOneWidget);
  });

  testWidgets('letter papers avoid hard drop shadows', (tester) async {
    final bloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'legacy',
            type: LetterType.legacy,
            createdAt: DateTime(2026, 5, 4),
            previewText: '那个关于截止日前夜的记录，让我想...',
            content: '嗨，\n\n那个关于截止日前夜的记录，让我想起你当时很需要支持。\n\nSarah',
            isRead: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(bloc));
    await tester.pump();

    final letterPaperContainers = tester.widgetList<Container>(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        if (widget.margin != const EdgeInsets.fromLTRB(28, 0, 28, 0)) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            (decoration.boxShadow?.isNotEmpty ?? false);
      }),
    );

    expect(letterPaperContainers, isNotEmpty);
    for (final container in letterPaperContainers) {
      final decoration = container.decoration as BoxDecoration;
      final shadows = decoration.boxShadow ?? const [];
      expect(shadows, isNotEmpty);
      for (final shadow in shadows) {
        expect(shadow.color.opacity <= 0.15, isTrue);
        expect(shadow.blurRadius <= 20, isTrue);
        expect(shadow.offset.dy <= 8, isTrue);
      }
    }
  });

  testWidgets('collapsed letter preview uses quiet paper-note typography',
      (tester) async {
    final bloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'legacy',
            type: LetterType.legacy,
            createdAt: DateTime(2026, 5, 4),
            previewText: '那个关于截止日前夜的记录，让我想...',
            content: '嗨，\n\n那个关于截止日前夜的记录，让我想起你当时很需要支持。\n\nSarah',
            isRead: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(bloc));
    await tester.pump();

    final previewFinder = find.textContaining('那个关于截止日前夜的记录');
    expect(previewFinder, findsWidgets);
    final preview = tester.widget<Text>(previewFinder.first);

    expect(preview.style?.fontSize, 15);
    expect(preview.style?.fontWeight, FontWeight.w400);
    expect(preview.style?.fontFamily, isNotNull);
  });

  testWidgets('formats period letters as ranges and welcome as single day',
      (tester) async {
    final bloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'weekly',
            type: LetterType.weekly,
            createdAt: DateTime(2026, 5, 20),
            content: '嗨，\n\n这是一封周信。\n\nSarah',
            isRead: true,
          ),
          _letter(
            id: 'legacy',
            type: LetterType.legacy,
            createdAt: DateTime(2026, 5, 4),
            weekStart: DateTime(2026, 4, 27),
            weekEnd: DateTime(2026, 5, 3),
            previewText: '旧周报迁移信。',
            content: '嗨，\n\n旧周报迁移信。\n\nSarah',
            isRead: true,
          ),
          _letter(
            id: 'welcome',
            type: LetterType.welcome,
            createdAt: DateTime(2026, 5, 20),
            previewText: '我是 Sarah。',
            content: '嗨，\n\n我是 Sarah。\n\nSarah',
            isRead: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(bloc));
    await tester.pump();

    expect(find.text('26.5.18 - 5.24'), findsOneWidget);
    expect(find.text('26.4.27 - 5.3'), findsOneWidget);

    final welcomeBloc = _FakeSarahBloc(
      SarahState(
        status: SarahStatus.success,
        letters: [
          _letter(
            id: 'welcome',
            type: LetterType.welcome,
            createdAt: DateTime(2026, 5, 20),
            previewText: '我是 Sarah。',
            content: '嗨，\n\n我是 Sarah。\n\nSarah',
            isRead: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildTestable(welcomeBloc));
    await tester.pump();

    expect(find.text('26.5.20 周三'), findsOneWidget);
  });
}

Widget _buildTestable(SarahBloc bloc) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: BlocProvider<SarahBloc>.value(
      value: bloc,
      child: const SarahScreen(),
    ),
  );
}

SarahLetter _letter({
  required String id,
  required LetterType type,
  required DateTime createdAt,
  required String content,
  DateTime? weekStart,
  DateTime? weekEnd,
  String? previewText,
  bool isRead = false,
}) {
  return SarahLetter(
    id: id,
    type: type,
    createdAt: createdAt,
    weekStart: weekStart,
    weekEnd: weekEnd,
    content: content,
    previewText: previewText,
    illustrationIndex: 1,
    isRead: isRead,
  );
}

class _FakeSarahBloc extends Fake implements SarahBloc {
  _FakeSarahBloc(this._state);

  final SarahState _state;
  final List<SarahEvent> events = [];

  @override
  SarahState get state => _state;

  @override
  Stream<SarahState> get stream => const Stream<SarahState>.empty();

  @override
  void add(SarahEvent event) {
    events.add(event);
  }

  @override
  Future<void> close() async {}
}
