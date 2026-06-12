import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/presentation/screens/intervention/deeper_support_screen.dart';

void main() {
  DeepAnalysisResult buildAnalysis({
    String type = 'selfCompassion',
    String? face,
    String? resonance,
    String? observedValue,
    bool enoughSignal = true,
  }) {
    return DeepAnalysisResult(
      type: type,
      title: '测试方法',
      methodLabel: 'Method',
      theorySource: '理论来源',
      overview: '方法概述',
      stuckPoint: observedValue ?? '占位卡点',
      groundedUnderstanding: '更贴近的理解',
      oneSmallStep: '先做一件小事',
      steadySentence: '给自己一句话',
      analyzedAt: DateTime(2026, 6, 12),
      face: face,
      enoughSignal: enoughSignal,
      resonance: resonance,
      observedLabel: observedValue == null ? null : '观察',
      observedValue: observedValue,
      truthLabel: observedValue == null ? null : '事实',
      truthValue: observedValue == null ? null : '新的理解',
    );
  }

  test('agent recommendation takes priority over keyword fallback', () {
    final analysis = NVCAnalysis(
      observation: '最近很累，完全没力气',
      feelings: const [],
      needs: const [],
      recommendedMethod: DeeperSupportType.releaseControl.name,
      analyzedAt: DateTime(2026, 6, 12),
    );

    expect(
      recommendedDeeperSupportType(
        transcription: '最近很累，完全没力气',
        analysis: analysis,
      ),
      DeeperSupportType.releaseControl,
    );
  });

  test('invalid agent recommendation falls back to keyword routing', () {
    final analysis = NVCAnalysis(
      observation: '最近很累，完全没力气',
      feelings: const [],
      needs: const [],
      recommendedMethod: 'unknownMethod',
      analyzedAt: DateTime(2026, 6, 12),
    );

    expect(
      recommendedDeeperSupportType(
        transcription: '最近很累，完全没力气',
        analysis: analysis,
      ),
      DeeperSupportType.gentleRecovery,
    );
  });

  testWidgets('complete returns the deep analysis result to the NVC page',
      (tester) async {
    DeepAnalysisResult? result;
    final analysis = buildAnalysis();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<DeepAnalysisResult>(
                MaterialPageRoute(
                  builder: (_) => DeeperSupportScreen(analysis: analysis),
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

  testWidgets('cannot save placeholder while agent result is loading',
      (tester) async {
    final completer = Completer<DeepAnalysisResult>();
    DeepAnalysisResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<DeepAnalysisResult>(
                MaterialPageRoute(
                  builder: (_) => DeeperSupportScreen(
                    analysis: buildAnalysis(),
                    transcription: '这是一段等待真实分析的记录',
                    analysisLoader: (_, __) => completer.future,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final loadingButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('deep-analysis-complete-button')),
    );
    expect(loadingButton.onPressed, isNull);
    expect(find.text('正在生成…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('deep-analysis-loading-state')),
      findsOneWidget,
    );
    expect(find.text('占位卡点'), findsNothing);
    expect(find.text('更贴近的理解'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('deep-analysis-complete-button')),
    );
    await tester.pump();
    expect(result, isNull);

    completer.complete(
      buildAnalysis(
        resonance: '这是真实智能体返回的内容',
        observedValue: '原来的想法',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('完成'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result?.resonance, '这是真实智能体返回的内容');
  });

  testWidgets('renders returned details even when enough signal is false',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeeperSupportScreen(
          analysis: buildAnalysis(
            face: 'low',
            enoughSignal: false,
            resonance: '遇到这种事，太痛了。',
            observedValue: '是不是我不够好',
          ),
        ),
      ),
    );

    expect(find.text('遇到这种事，太痛了。'), findsOneWidget);
    expect(find.text('是不是我不够好'), findsOneWidget);
    expect(find.text('新的理解'), findsOneWidget);
    expect(find.text('更贴近的理解'), findsOneWidget);
    expect(find.text('先做一件小事'), findsOneWidget);
  });

  testWidgets('ACT observed thought is not struck through', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeeperSupportScreen(
          analysis: buildAnalysis(
            type: DeeperSupportType.releaseControl.name,
            observedValue: '我必须现在把所有事情想清楚',
          ),
        ),
      ),
    );

    final observed = tester.widget<Text>(
      find.byKey(const ValueKey('deep-analysis-observed-value')),
    );
    expect(observed.style?.decoration, TextDecoration.none);
  });

  testWidgets('CBT observed conclusion is struck through', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeeperSupportScreen(
          analysis: buildAnalysis(
            type: DeeperSupportType.cognitiveReframe.name,
            observedValue: '一次没做好就说明我不行',
          ),
        ),
      ),
    );

    final observed = tester.widget<Text>(
      find.byKey(const ValueKey('deep-analysis-observed-value')),
    );
    expect(observed.style?.decoration, TextDecoration.lineThrough);
  });
}
