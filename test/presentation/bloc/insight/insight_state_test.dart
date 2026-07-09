import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/insight_report.dart';
import 'package:mindflow/domain/entities/weekly_analysis.dart';
import 'package:mindflow/presentation/bloc/insight/insight_state.dart';

void main() {
  test('InsightState copyWith clears report without dropping weekly analysis',
      () {
    const analysis = WeeklyAnalysis(
      weekRange: '2026-03-16 ~ 2026-03-22',
      totalRecords: 5,
      activeDays: 4,
      longestStreak: 2,
      topMood: '焦虑',
      topNeed: '支持',
      topMoods: [
        WeeklyTagStat(label: '焦虑', count: 3, percentage: 60),
      ],
      topNeeds: [
        WeeklyTagStat(label: '支持', count: 2, percentage: 40),
      ],
      peakTimeBucket: '晚上',
      busiestWeekday: '周二',
      moodTaggedCount: 4,
      needTaggedCount: 3,
      coverageSummary: '4/5 条记录包含心情，3/5 条记录包含需求',
      changesSummary: ['本周记录数较上周增加 2 条'],
    );

    final state = InsightState.initial().copyWith(
      status: InsightStatus.success,
      currentReport: InsightReport(
        id: 'report-1',
        reportType: '每周洞察报告',
        emotionOverview: const EmotionOverview(summary: 'summary'),
        highFrequencyEmotions: const [],
        patternHypothesis: const PatternHypothesis(
          text: '{trigger} -> {need}',
          highlightTags: [],
        ),
        actionSuggestions: const [],
        weekRange: '2026-03-16 ~ 2026-03-22',
        createdAt: DateTime(2026, 3, 22, 10),
      ),
      weeklyAnalysis: analysis,
    );

    expect(state.weeklyAnalysis, analysis);

    final cleared = state.copyWith(clearReport: true);

    expect(cleared.currentReport, isNull);
    expect(cleared.weeklyAnalysis, analysis);
  });
}
