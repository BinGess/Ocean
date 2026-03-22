import 'package:equatable/equatable.dart';

class WeeklyTagStat extends Equatable {
  const WeeklyTagStat({
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String label;
  final int count;
  final double percentage;

  @override
  List<Object?> get props => [label, count, percentage];
}

class WeeklyAnalysis extends Equatable {
  const WeeklyAnalysis({
    required this.weekRange,
    required this.totalRecords,
    required this.activeDays,
    required this.longestStreak,
    required this.topMood,
    required this.topNeed,
    required this.topMoods,
    required this.topNeeds,
    required this.peakTimeBucket,
    required this.busiestWeekday,
    required this.moodTaggedCount,
    required this.needTaggedCount,
    required this.coverageSummary,
    required this.changesSummary,
  });

  final String weekRange;
  final int totalRecords;
  final int activeDays;
  final int longestStreak;
  final String? topMood;
  final String? topNeed;
  final List<WeeklyTagStat> topMoods;
  final List<WeeklyTagStat> topNeeds;
  final String? peakTimeBucket;
  final String? busiestWeekday;
  final int moodTaggedCount;
  final int needTaggedCount;
  final String coverageSummary;
  final List<String> changesSummary;

  @override
  List<Object?> get props => [
        weekRange,
        totalRecords,
        activeDays,
        longestStreak,
        topMood,
        topNeed,
        topMoods,
        topNeeds,
        peakTimeBucket,
        busiestWeekday,
        moodTaggedCount,
        needTaggedCount,
        coverageSummary,
        changesSummary,
      ];
}
