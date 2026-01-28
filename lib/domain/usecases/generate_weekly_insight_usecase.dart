// 生成周洞察用例
// 分析一周的记录并生成洞察

import 'package:uuid/uuid.dart';
import '../entities/record.dart';
import '../entities/weekly_insight.dart';
import '../repositories/record_repository.dart';
import '../repositories/ai_repository.dart';
import '../repositories/insight_repository.dart';
import 'base_usecase.dart';

class GenerateWeeklyInsightParams {
  final String weekRange;
  final DateTime startDate;
  final DateTime endDate;

  GenerateWeeklyInsightParams({
    required this.weekRange,
    required this.startDate,
    required this.endDate,
  });

  /// 为当前周创建参数
  factory GenerateWeeklyInsightParams.forCurrentWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final startStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final endStr =
        '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

    return GenerateWeeklyInsightParams(
      weekRange: '$startStr ~ $endStr',
      startDate: weekStart,
      endDate: weekEnd,
    );
  }
}

class GenerateWeeklyInsightUseCase
    extends UseCase<WeeklyInsight, GenerateWeeklyInsightParams> {
  final RecordRepository recordRepository;
  final AIRepository aiRepository;
  final InsightRepository insightRepository;

  GenerateWeeklyInsightUseCase({
    required this.recordRepository,
    required this.aiRepository,
    required this.insightRepository,
  });

  @override
  Future<WeeklyInsight> call(GenerateWeeklyInsightParams params) async {
    // 1. 检查是否已有本周洞察
    final existing = await insightRepository.getWeeklyInsight(params.weekRange);
    if (existing != null) {
      return existing;
    }

    // 2. 获取本周所有记录
    final records = await recordRepository.getRecordsByDateRange(
      params.startDate,
      params.endDate,
    );

    // 如果没有记录，返回空洞察
    if (records.isEmpty) {
      throw Exception('本周没有足够的记录生成洞察');
    }

    // 3. 使用 AI 生成洞察
    final recordIds = records.map((r) => r.id).toList();
    final aiInsight = await aiRepository.generateWeeklyInsight(recordIds);

    // 4. 统计需要出现频率
    final needStatistics = _calculateNeedStatistics(records);

    // 5. 创建完整的周洞察
    final now = DateTime.now();
    final insight = WeeklyInsight(
      id: const Uuid().v4(),
      weekRange: params.weekRange,
      startDate: params.startDate,
      endDate: params.endDate,
      emotionalPatterns: aiInsight.emotionalPatterns,
      microExperiments: aiInsight.microExperiments,
      needStatistics: needStatistics,
      aiSummary: aiInsight.aiSummary,
      referencedRecords: records.map((r) => r.id).toList(),
      createdAt: now,
      updatedAt: now,
    );

    // 6. 保存洞察
    return await insightRepository.createWeeklyInsight(insight);
  }

  /// 计算需要统计
  List<NeedStatistics> _calculateNeedStatistics(List<Record> records) {
    final needCounts = <String, int>{};
    var totalNeeds = 0;

    // 统计每个需要出现的次数
    for (final record in records) {
      if (record.needs != null) {
        for (final need in record.needs!) {
          needCounts[need] = (needCounts[need] ?? 0) + 1;
          totalNeeds++;
        }
      }
    }

    // 转换为统计对象
    final statistics = needCounts.entries.map((entry) {
      final percentage = totalNeeds > 0 ? (entry.value / totalNeeds) * 100 : 0.0;
      return NeedStatistics(
        need: entry.key,
        count: entry.value,
        percentage: percentage.toDouble(),
      );
    }).toList();

    // 按出现次数降序排序
    statistics.sort((a, b) => b.count.compareTo(a.count));

    return statistics;
  }
}
