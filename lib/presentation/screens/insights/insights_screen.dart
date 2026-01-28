import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/weekly_insight.dart';
import '../../bloc/insight/insight_bloc.dart';
import '../../bloc/insight/insight_state.dart';
import '../../bloc/insight/insight_event.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    // 加载当前周的洞察
    context.read<InsightBloc>().add(const InsightGenerateCurrentWeek());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {
              // TODO: 实现分享功能
            },
          ),
        ],
      ),
      body: BlocBuilder<InsightBloc, InsightState>(
        builder: (context, state) {
          if (state.status == InsightStatus.loading ||
              state.status == InsightStatus.generating) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在生成洞察...'),
                ],
              ),
            );
          }

          if (state.status == InsightStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.errorMessage ?? '加载失败',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<InsightBloc>().add(const InsightGenerateCurrentWeek());
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (state.currentInsight == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.insights,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无洞察数据',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '记录更多内容后将自动生成',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildInsightContent(context, state.currentInsight!);
        },
      ),
    );
  }

  Widget _buildInsightContent(BuildContext context, WeeklyInsight insight) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 周范围标题
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  _formatWeekRange(insight.weekRange),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '每周洞察报告',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 情绪概览卡片
          if (insight.aiSummary != null) _buildEmotionOverviewCard(insight),

          const SizedBox(height: 12),

          // 高频情绪列表
          if (insight.emotionalPatterns.isNotEmpty)
            _buildHighFrequencyEmotionsSection(insight),

          const SizedBox(height: 12),

          // 模式情绪卡片
          if (insight.emotionalPatterns.isNotEmpty)
            _buildEmotionalPatternsSection(insight),

          const SizedBox(height: 12),

          // 微实验建议
          if (insight.microExperiments.isNotEmpty)
            _buildMicroExperimentsSection(insight),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 情绪概览卡片
  Widget _buildEmotionOverviewCard(WeeklyInsight insight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                '情绪概览',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.aiSummary ?? '',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 20),
          // 7个圆点表示一周
          _buildWeekVisualization(insight),
        ],
      ),
    );
  }

  /// 一周可视化（7个圆点）
  Widget _buildWeekVisualization(WeeklyInsight insight) {
    // 根据情绪数据计算每天的颜色
    // 这里简化处理，实际应该根据每天的情绪强度决定颜色
    final colors = [
      Colors.blue[300]!,
      Colors.orange[300]!,
      Colors.red[300]!,
      Colors.orange[400]!,
      Colors.red[400]!,
      Colors.blue[400]!,
      Colors.grey[300]!,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        7,
        (index) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: colors[index],
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  /// 高频情绪列表
  Widget _buildHighFrequencyEmotionsSection(WeeklyInsight insight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '高频情绪',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...insight.emotionalPatterns.take(3).map((pattern) {
            return _buildEmotionItem(pattern);
          }),
        ],
      ),
    );
  }

  /// 单个情绪项
  Widget _buildEmotionItem(EmotionalPattern pattern) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${pattern.pattern}"',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getRelativeTime(pattern.relatedRecords.length),
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 模式情绪卡片
  Widget _buildEmotionalPatternsSection(WeeklyInsight insight) {
    final mainPattern = insight.emotionalPatterns.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              const Text(
                '模式情绪',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF4B5563),
              ),
              children: [
                const TextSpan(text: '看起来 '),
                TextSpan(
                  text: mainPattern.pattern,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(text: ' 似乎触发了你对 心对 '),
                TextSpan(
                  text: _getMainNeed(insight),
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(text: ' 的渴烈需要。'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 微实验建议卡片
  Widget _buildMicroExperimentsSection(WeeklyInsight insight) {
    final experiment = insight.microExperiments.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                '微实验建议',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            experiment.suggestion,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            experiment.rationale,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化周范围
  String _formatWeekRange(String weekRange) {
    // weekRange 格式: "2025-01-13 ~ 2025-01-19"
    final parts = weekRange.split(' ~ ');
    if (parts.length == 2) {
      try {
        final start = DateTime.parse(parts[0]);
        final end = DateTime.parse(parts[1]);
        final startFormatted = DateFormat('MMM d', 'en_US').format(start);
        final endFormatted = DateFormat('MMM d', 'en_US').format(end);
        return '$startFormatted - $endFormatted';
      } catch (e) {
        return weekRange;
      }
    }
    return weekRange;
  }

  /// 获取相对时间描述
  String _getRelativeTime(int recordCount) {
    // 简化处理，可以根据 relatedRecords 的实际时间计算
    if (recordCount > 0) {
      return '周二 - 16:00'; // 示例值
    }
    return '';
  }

  /// 获取主要需要
  String _getMainNeed(WeeklyInsight insight) {
    if (insight.needStatistics != null && insight.needStatistics!.isNotEmpty) {
      return insight.needStatistics!.first.need;
    }
    return '胜任感与心流';
  }
}
