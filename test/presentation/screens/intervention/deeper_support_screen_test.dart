import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/presentation/screens/intervention/deeper_support_screen.dart';

void main() {
  testWidgets('complete returns the deep analysis result to the NVC page',
      (tester) async {
    DeepAnalysisResult? result;
    final analysis = DeepAnalysisResult(
      type: DeeperSupportType.selfCompassion.name,
      title: '站回自己这边',
      methodLabel: 'Self-Compassion',
      theorySource: '源自自我同情与慈悲聚焦取向',
      overview: '帮助你在困难里重新站回自己这一边。',
      stuckPoint: '你开始把压力转成了自责。',
      groundedUnderstanding: '自责说明你重视，不等于你很差劲。',
      oneSmallStep: '先把责任和自我否定分开。',
      steadySentence: '我可以先停止追责自己。',
      analyzedAt: DateTime(2026, 6, 7),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<DeepAnalysisResult>(
                MaterialPageRoute(
                  builder: (_) => DeeperSupportScreen(
                    analysis: analysis,
                  ),
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(result?.type, DeeperSupportType.selfCompassion.name);
  });
}
