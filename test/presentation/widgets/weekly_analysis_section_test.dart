import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/weekly_analysis.dart';
import 'package:mindflow/presentation/widgets/insights/weekly_analysis_section.dart';

void main() {
  testWidgets('WeeklyAnalysisSection renders overview and change summaries',
      (tester) async {
    const analysis = WeeklyAnalysis(
      weekRange: '2026-03-16 ~ 2026-03-22',
      totalRecords: 8,
      activeDays: 5,
      longestStreak: 3,
      topMood: '焦虑',
      topNeed: '支持',
      topMoods: [
        WeeklyTagStat(label: '焦虑', count: 4, percentage: 50),
        WeeklyTagStat(label: '平静', count: 2, percentage: 25),
      ],
      topNeeds: [
        WeeklyTagStat(label: '被理解与稳定支持', count: 3, percentage: 37.5),
        WeeklyTagStat(label: '休息', count: 2, percentage: 25),
      ],
      peakTimeBucket: '晚上',
      busiestWeekday: '周三',
      moodTaggedCount: 6,
      needTaggedCount: 4,
      coverageSummary: '6/8 条记录包含心情，4/8 条记录包含需求',
      changesSummary: [
        '本周记录数较上周增加 2 条',
        '“焦虑”比上周多出现 1 次',
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyAnalysisSection(analysis: analysis),
          ),
        ),
      ),
    );

    expect(find.text('本周概览'), findsOneWidget);
    expect(find.text('情绪与需求'), findsOneWidget);
    expect(find.text('节律与变化'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('左右滑动查看'), findsOneWidget);
    expect(find.text('高频心情'), findsOneWidget);
    expect(find.text('高频需求'), findsOneWidget);
    expect(find.text('记录数'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('高峰时段'), findsOneWidget);
    expect(find.text('最密集日'), findsOneWidget);
    expect(find.text('最多心情'), findsNothing);
    expect(find.text('最多需求'), findsNothing);
    expect(find.text('焦虑'), findsWidgets);
    expect(find.text('被理解与稳定支持'), findsNothing);
    expect(find.text('晚上'), findsOneWidget);
    expect(find.text('周三'), findsOneWidget);
    expect(find.text('6/8 条记录包含心情，4/8 条记录包含需求'), findsNothing);
    expect(
      find.text('本周记录数较上周增加 2 条 · “焦虑”比上周多出现 1 次'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('4 次 · 50%'), findsOneWidget);
    expect(find.text('01'), findsWidgets);

    await tester.tap(find.text('高频需求'));
    await tester.pumpAndSettle();

    expect(find.text('被理解与稳定支持'), findsOneWidget);
    expect(find.text('3 次 · 38%'), findsOneWidget);
  });

  testWidgets('compact emotion and needs card keeps tag rows visible',
      (tester) async {
    const analysis = WeeklyAnalysis(
      weekRange: '2026-03-16 ~ 2026-03-22',
      totalRecords: 8,
      activeDays: 5,
      longestStreak: 3,
      topMood: '焦虑',
      topNeed: '支持',
      topMoods: [
        WeeklyTagStat(label: '被理解与稳定支持', count: 4, percentage: 50),
        WeeklyTagStat(label: '需要一个可以慢慢整理情绪的安全空间', count: 3, percentage: 38),
        WeeklyTagStat(label: '想要休息和重新获得身体能量', count: 2, percentage: 25),
      ],
      topNeeds: [
        WeeklyTagStat(label: '清晰表达界限并被尊重', count: 3, percentage: 38),
        WeeklyTagStat(label: '稳定陪伴', count: 2, percentage: 25),
      ],
      peakTimeBucket: '晚上',
      busiestWeekday: '周三',
      moodTaggedCount: 6,
      needTaggedCount: 4,
      coverageSummary: '6/8 条记录包含心情，4/8 条记录包含需求',
      changesSummary: ['本周记录数较上周增加 2 条'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyAnalysisSection(
              analysis: analysis,
              showOverview: false,
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('被理解与稳定支持'), findsOneWidget);
    expect(find.text('需要一个可以慢慢整理情绪的安全空间'), findsOneWidget);
    expect(find.text('想要休息和重新获得身体能量'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
