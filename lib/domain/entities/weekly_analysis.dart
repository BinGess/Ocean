import 'package:equatable/equatable.dart';

class HourlyCount extends Equatable {
  const HourlyCount({required this.hour, required this.count});

  final int hour; // UTC 小时 (0–23)
  final int count;

  @override
  List<Object?> get props => [hour, count];
}

class WeeklyTagStat extends Equatable {
  const WeeklyTagStat({
    required this.label,
    required this.count,
    required this.percentage,
    this.avgIntensity,
    this.vsLastWeek,
  });

  final String label;
  final int count;
  final double percentage;

  /// 来自 nvc.feelings.intensity 的平均强度（1–5），仅 mood 有；moods 字段来源时为 null
  final double? avgIntensity;

  /// 本周 count − 上周同名标签 count，可为负；null 表示无对比数据
  final int? vsLastWeek;

  factory WeeklyTagStat.fromServerMoodJson(Map<String, dynamic> json) {
    return WeeklyTagStat(
      label: json['label'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      avgIntensity: (json['avg_intensity'] as num?)?.toDouble(),
      vsLastWeek: json['vs_last_week'] as int?,
    );
  }

  factory WeeklyTagStat.fromServerNeedJson(Map<String, dynamic> json) {
    return WeeklyTagStat(
      label: json['label'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      vsLastWeek: json['vs_last_week'] as int?,
    );
  }

  @override
  List<Object?> get props => [label, count, percentage, avgIntensity, vsLastWeek];
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
    this.peakTimeTopHours,
    this.hourlyDistribution,
    this.moodCoverageRate,
    this.needCoverageRate,
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

  /// 最活跃的 UTC 小时列表（最多 3 个），需客户端转本地时区展示
  final List<int>? peakTimeTopHours;

  /// 各小时记录分布（仅含 count > 0 的项，UTC 小时）
  final List<HourlyCount>? hourlyDistribution;

  final double? moodCoverageRate;
  final double? needCoverageRate;

  factory WeeklyAnalysis.fromServerJson(Map<String, dynamic> json) {
    final overview = (json['overview'] as Map?)?.cast<String, dynamic>() ?? {};
    final peakTime = (json['peak_time'] as Map?)?.cast<String, dynamic>();
    final emotions = (json['emotions'] as Map?)?.cast<String, dynamic>() ?? {};
    final coverage = (emotions['coverage'] as Map?)?.cast<String, dynamic>() ?? {};
    final changesVsLastWeek =
        (json['changes_vs_last_week'] as Map?)?.cast<String, dynamic>() ?? {};

    final topMoodsList = ((emotions['top_moods'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => WeeklyTagStat.fromServerMoodJson(e.cast<String, dynamic>()))
        .take(5)
        .toList();

    final topNeedsList = ((emotions['top_needs'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => WeeklyTagStat.fromServerNeedJson(e.cast<String, dynamic>()))
        .take(5)
        .toList();

    final topHoursRaw = (peakTime?['top_hours'] as List?)?.cast<int>();
    final hourlyRaw = (peakTime?['hourly_distribution'] as List?) ?? [];
    final hourlyDist = hourlyRaw
        .whereType<Map>()
        .map((e) => HourlyCount(
              hour: e['hour'] as int? ?? 0,
              count: e['count'] as int? ?? 0,
            ))
        .toList();

    // 服务端 bucket 基于 UTC，用 top_hours 转本地时区重新推导
    final bucket = topHoursRaw != null && topHoursRaw.isNotEmpty
        ? _derivePeakBucketFromUtc(topHoursRaw.first)
        : peakTime?['bucket'] as String?;

    final changesSummary = _buildChangesSummary(changesVsLastWeek);

    final moodTaggedCount = coverage['records_with_mood'] as int? ?? 0;
    final needTaggedCount = coverage['records_with_need'] as int? ?? 0;
    final totalRecords = overview['total_records'] as int? ?? 0;

    return WeeklyAnalysis(
      weekRange: json['week_range'] as String? ?? '',
      totalRecords: totalRecords,
      activeDays: overview['active_days'] as int? ?? 0,
      longestStreak: overview['longest_streak'] as int? ?? 0,
      topMood: topMoodsList.isNotEmpty ? topMoodsList.first.label : null,
      topNeed: topNeedsList.isNotEmpty ? topNeedsList.first.label : null,
      topMoods: topMoodsList,
      topNeeds: topNeedsList,
      peakTimeBucket: bucket,
      busiestWeekday: overview['busiest_weekday'] as String?,
      moodTaggedCount: moodTaggedCount,
      needTaggedCount: needTaggedCount,
      coverageSummary:
          '$moodTaggedCount/$totalRecords 条记录包含心情，$needTaggedCount/$totalRecords 条记录包含需求',
      changesSummary: changesSummary,
      peakTimeTopHours: topHoursRaw,
      hourlyDistribution: hourlyDist.isEmpty ? null : hourlyDist,
      moodCoverageRate: (coverage['mood_coverage_rate'] as num?)?.toDouble(),
      needCoverageRate: (coverage['need_coverage_rate'] as num?)?.toDouble(),
    );
  }

  static String _derivePeakBucketFromUtc(int utcHour) {
    final offset = DateTime.now().timeZoneOffset.inHours;
    final localHour = (utcHour + offset) % 24;
    if (localHour >= 6 && localHour <= 11) return '早上';
    if (localHour >= 12 && localHour <= 17) return '下午';
    if (localHour >= 18 && localHour <= 22) return '晚上';
    return '凌晨';
  }

  static List<String> _buildChangesSummary(Map<String, dynamic> changes) {
    final result = <String>[];

    final recordsDelta = changes['records_delta'] as int? ?? 0;
    if (recordsDelta > 0) {
      result.add('本周记录数较上周增加 $recordsDelta 条');
    } else if (recordsDelta < 0) {
      result.add('本周记录数较上周减少 ${recordsDelta.abs()} 条');
    }

    for (final shift in ((changes['mood_shifts'] as List?) ?? []).whereType<Map>()) {
      final label = shift['label'] as String? ?? '';
      final delta = shift['delta'] as int? ?? 0;
      final direction = shift['direction'] as String? ?? '';
      if (direction == 'up') {
        result.add('"$label"比上周多出现 $delta 次');
      } else if (direction == 'down') {
        result.add('"$label"比上周少出现 ${delta.abs()} 次');
      }
    }

    for (final shift in ((changes['need_shifts'] as List?) ?? []).whereType<Map>()) {
      final label = shift['label'] as String? ?? '';
      final delta = shift['delta'] as int? ?? 0;
      final direction = shift['direction'] as String? ?? '';
      if (direction == 'up') {
        result.add('"$label"比上周多出现 $delta 次');
      } else if (direction == 'down') {
        result.add('"$label"比上周少出现 ${delta.abs()} 次');
      }
    }

    return result;
  }

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
        peakTimeTopHours,
        hourlyDistribution,
        moodCoverageRate,
        needCoverageRate,
      ];
}
