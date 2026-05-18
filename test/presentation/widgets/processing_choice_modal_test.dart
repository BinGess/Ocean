import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/widgets/processing_choice_modal.dart';

void main() {
  testWidgets('only-record save exposes and returns a save date',
      (tester) async {
    ProcessingResult? selectedResult;

    await tester.pumpWidget(
      _buildTestable(
        ProcessingChoiceModal(
          transcription: '今天有点累，但想记下来',
          onSelect: (result) => selectedResult = result,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('保存日期'), findsOneWidget);

    await tester.tap(find.text('仅记录文本'));
    await tester.pumpAndSettle();

    expect(selectedResult?.mode, ProcessingMode.onlyRecord);
    expect(
      (selectedResult as dynamic).selectedDateTime,
      isA<DateTime>(),
    );
  });

  testWidgets('save date selector uses Cupertino date picker', (tester) async {
    await tester.pumpWidget(
      _buildTestable(
        ProcessingChoiceModal(
          transcription: '给纯文本记录选择保存日期',
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('保存日期'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });

  testWidgets('processing modal labels follow English locale', (tester) async {
    await tester.pumpWidget(
      _buildTestable(
        ProcessingChoiceModal(
          transcription: 'A quick note',
          onSelect: (_) {},
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pump();

    expect(find.text('Recording Complete'), findsOneWidget);
    expect(find.text('Save Date'), findsOneWidget);
    expect(find.text('Choose how to save'), findsOneWidget);
    expect(find.text('Save Text Only'), findsOneWidget);
    expect(find.text('录音完成'), findsNothing);
    expect(find.text('仅记录文本'), findsNothing);
  });
}

Widget _buildTestable(
  Widget child, {
  Locale locale = const Locale('zh'),
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
    home: Scaffold(body: child),
  );
}
