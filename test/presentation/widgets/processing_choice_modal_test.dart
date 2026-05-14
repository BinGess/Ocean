import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/presentation/widgets/processing_choice_modal.dart';

void main() {
  testWidgets('only-record save exposes and returns a save date',
      (tester) async {
    ProcessingResult? selectedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProcessingChoiceModal(
            transcription: '今天有点累，但想记下来',
            onSelect: (result) => selectedResult = result,
          ),
        ),
      ),
    );

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
      MaterialApp(
        home: Scaffold(
          body: ProcessingChoiceModal(
            transcription: '给纯文本记录选择保存日期',
            onSelect: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('保存日期'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });
}
