// 生成洞察报告用例
// 分析一周的记录并生成洞察报告

import '../entities/record.dart';
import '../entities/insight_report.dart';
import '../repositories/record_repository.dart';
import '../repositories/ai_repository.dart';
import 'base_usecase.dart';

class GenerateInsightReportParams {
  final String weekRange;
  final DateTime startDate;
  final DateTime endDate;

  GenerateInsightReportParams({
    required this.weekRange,
    required this.startDate,
    required this.endDate,
  });

  /// 为当前周创建参数
  factory GenerateInsightReportParams.forCurrentWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final startStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final endStr =
        '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

    return GenerateInsightReportParams(
      weekRange: '$startStr ~ $endStr',
      startDate: weekStart,
      endDate: weekEnd,
    );
  }
}

class GenerateInsightReportUseCase
    extends UseCase<InsightReport, GenerateInsightReportParams> {
  final RecordRepository recordRepository;
  final AIRepository aiRepository;

  GenerateInsightReportUseCase({
    required this.recordRepository,
    required this.aiRepository,
  });

  @override
  Future<InsightReport> call(GenerateInsightReportParams params) async {
    // 1. 获取本周所有记录
    final records = await recordRepository.getRecordsByDateRange(
      params.startDate,
      params.endDate,
    );

    // 如果没有记录，抛出异常
    if (records.isEmpty) {
      throw Exception('本周没有足够的记录生成洞察');
    }

    // 2. 将记录转换为 API 请求格式
    final requestRecords = _convertToRequestRecords(records);

    // 3. 调用 AI 生成洞察报告
    final report = await aiRepository.generateInsightReport(
      requestRecords,
      params.weekRange,
    );

    return report;
  }

  /// 将记录转换为洞察请求格式
  /// 格式：2026-01-22 周四 21:30
  List<InsightRequestRecord> _convertToRequestRecords(List<Record> records) {
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return records.map((record) {
      final date = record.createdAt;
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final weekDay = weekDays[date.weekday - 1];
      final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      return InsightRequestRecord(
        recordTime: '$dateStr $weekDay $timeStr',
        content: record.transcription,
      );
    }).toList();
  }
}
