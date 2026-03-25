import '../entities/record.dart';
import '../entities/weekly_analysis.dart';
import '../repositories/record_repository.dart';
import 'base_usecase.dart';

class BuildWeeklyAnalysisParams {
  BuildWeeklyAnalysisParams({
    required this.weekRange,
    required this.startDate,
    required this.endDate,
  });

  final String weekRange;
  final DateTime startDate;
  final DateTime endDate;
}

class BuildWeeklyAnalysisUseCase
    extends UseCase<WeeklyAnalysis, BuildWeeklyAnalysisParams> {
  BuildWeeklyAnalysisUseCase({required this.recordRepository});

  final RecordRepository recordRepository;

  static const _weekdayLabels = <int, String>{
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };

  static const _timeBucketOrder = ['深夜', '早晨', '下午', '晚上'];

  @override
  Future<WeeklyAnalysis> call(BuildWeeklyAnalysisParams params) async {
    final currentRecords = await recordRepository.getRecordsByDateRange(
      params.startDate,
      params.endDate,
    );

    if (currentRecords.isEmpty) {
      throw Exception('本周没有足够的记录生成洞察');
    }

    final previousStartDate =
        params.startDate.subtract(const Duration(days: 7));
    final previousEndDate = params.endDate.subtract(const Duration(days: 7));
    final previousRecords = await recordRepository.getRecordsByDateRange(
      previousStartDate,
      previousEndDate,
    );

    final moodResult = _buildTagStats(
      currentRecords,
      extractor: _extractMoodTags,
    );
    final needResult = _buildTagStats(
      currentRecords,
      extractor: _extractNeedTags,
    );
    final previousMoodCounts = _buildTagCounts(
      previousRecords,
      extractor: _extractMoodTags,
    );
    final previousNeedCounts = _buildTagCounts(
      previousRecords,
      extractor: _extractNeedTags,
    );

    final totalRecords = currentRecords.length;
    final moodTaggedCount = currentRecords
        .where((record) => _extractMoodTags(record).isNotEmpty)
        .length;
    final needTaggedCount = currentRecords
        .where((record) => _extractNeedTags(record).isNotEmpty)
        .length;

    return WeeklyAnalysis(
      weekRange: params.weekRange,
      totalRecords: totalRecords,
      activeDays: _countActiveDays(currentRecords),
      longestStreak: _countLongestStreak(currentRecords),
      topMood: moodResult.isNotEmpty ? moodResult.first.label : null,
      topNeed: needResult.isNotEmpty ? needResult.first.label : null,
      topMoods: moodResult.take(3).toList(),
      topNeeds: needResult.take(3).toList(),
      peakTimeBucket: _findPeakTimeBucket(currentRecords),
      busiestWeekday: _findBusiestWeekday(currentRecords),
      moodTaggedCount: moodTaggedCount,
      needTaggedCount: needTaggedCount,
      coverageSummary:
          '$moodTaggedCount/$totalRecords 条记录包含心情，$needTaggedCount/$totalRecords 条记录包含需求',
      changesSummary: _buildChangesSummary(
        totalRecords: totalRecords,
        previousRecordsCount: previousRecords.length,
        currentTopMood: moodResult.isNotEmpty ? moodResult.first : null,
        currentTopNeed: needResult.isNotEmpty ? needResult.first : null,
        previousMoodCounts: previousMoodCounts,
        previousNeedCounts: previousNeedCounts,
      ),
    );
  }

  List<WeeklyTagStat> _buildTagStats(
    List<Record> records, {
    required List<String> Function(Record) extractor,
  }) {
    final counts = _buildTagCounts(records, extractor: extractor);
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    final stats = counts.entries
        .map(
          (entry) => WeeklyTagStat(
            label: entry.key,
            count: entry.value,
            percentage: total == 0 ? 0 : (entry.value / total) * 100,
          ),
        )
        .toList();
    stats.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) return countCompare;
      return a.label.compareTo(b.label);
    });
    return stats;
  }

  Map<String, int> _buildTagCounts(
    List<Record> records, {
    required List<String> Function(Record) extractor,
  }) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final tag in extractor(record)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  int _countActiveDays(List<Record> records) {
    return records
        .map((record) => DateTime(record.createdAt.year, record.createdAt.month,
            record.createdAt.day))
        .toSet()
        .length;
  }

  int _countLongestStreak(List<Record> records) {
    final days = records
        .map((record) => DateTime(record.createdAt.year, record.createdAt.month,
            record.createdAt.day))
        .toSet()
        .toList()
      ..sort();
    if (days.isEmpty) return 0;

    var longest = 1;
    var current = 1;
    for (var index = 1; index < days.length; index++) {
      if (days[index].difference(days[index - 1]).inDays == 1) {
        current += 1;
      } else {
        current = 1;
      }
      if (current > longest) {
        longest = current;
      }
    }
    return longest;
  }

  String? _findPeakTimeBucket(List<Record> records) {
    if (records.isEmpty) return null;
    final counts = <String, int>{};
    for (final record in records) {
      final bucket = _toTimeBucket(record.createdAt.hour);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return _timeBucketOrder
            .indexOf(a.key)
            .compareTo(_timeBucketOrder.indexOf(b.key));
      });
    return ordered.first.key;
  }

  String? _findBusiestWeekday(List<Record> records) {
    if (records.isEmpty) return null;
    final counts = <int, int>{};
    for (final record in records) {
      counts[record.createdAt.weekday] =
          (counts[record.createdAt.weekday] ?? 0) + 1;
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return _weekdayLabels[ordered.first.key];
  }

  List<String> _buildChangesSummary({
    required int totalRecords,
    required int previousRecordsCount,
    required WeeklyTagStat? currentTopMood,
    required WeeklyTagStat? currentTopNeed,
    required Map<String, int> previousMoodCounts,
    required Map<String, int> previousNeedCounts,
  }) {
    final result = <String>[];
    final recordsDelta = totalRecords - previousRecordsCount;
    if (recordsDelta > 0) {
      result.add('本周记录数较上周增加 $recordsDelta 条');
    } else if (recordsDelta < 0) {
      result.add('本周记录数较上周减少 ${recordsDelta.abs()} 条');
    }

    if (currentTopMood != null) {
      final previousCount = previousMoodCounts[currentTopMood.label] ?? 0;
      final delta = currentTopMood.count - previousCount;
      if (delta > 0) {
        result.add('“${currentTopMood.label}”比上周多出现 $delta 次');
      } else if (delta < 0) {
        result.add('“${currentTopMood.label}”比上周少出现 ${delta.abs()} 次');
      }
    }

    if (currentTopNeed != null) {
      final previousCount = previousNeedCounts[currentTopNeed.label] ?? 0;
      final delta = currentTopNeed.count - previousCount;
      if (delta > 0) {
        result.add('“${currentTopNeed.label}”比上周多出现 $delta 次');
      } else if (delta < 0) {
        result.add('“${currentTopNeed.label}”比上周少出现 ${delta.abs()} 次');
      }
    }

    return result;
  }

  List<String> _extractMoodTags(Record record) {
    final directTags = _normalizeTags(record.moods);
    if (directTags.isNotEmpty) return directTags;
    return record.nvc?.feelings
            .map((feeling) => feeling.feeling.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const [];
  }

  List<String> _extractNeedTags(Record record) {
    final directTags = _normalizeTags(record.needs);
    if (directTags.isNotEmpty) return directTags;
    return record.nvc?.needs
            .map((need) => need.need.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const [];
  }

  List<String> _normalizeTags(List<String>? tags) {
    if (tags == null || tags.isEmpty) return const [];
    final splitPattern = RegExp(r'[，,、；;|/\\\n]+');
    final normalized = <String>[];
    final seen = <String>{};
    for (final item in tags) {
      for (final raw in item.split(splitPattern)) {
        final tag = raw.trim();
        if (tag.isEmpty || !seen.add(tag)) continue;
        normalized.add(tag);
      }
    }
    return normalized;
  }

  String _toTimeBucket(int hour) {
    if (hour >= 5 && hour <= 11) return '早晨';
    if (hour >= 12 && hour <= 17) return '下午';
    if (hour >= 18 && hour <= 22) return '晚上';
    return '深夜';
  }
}
