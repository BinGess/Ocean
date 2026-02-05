import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/insight_report.dart';
import '../../bloc/insight/insight_bloc.dart';
import '../../bloc/insight/insight_state.dart';
import '../../bloc/insight/insight_event.dart';
import 'history_reports_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _refreshController;
  bool _isRefreshing = false;
  @override
  void initState() {
    super.initState();
    // 加载当前周的洞察（优先使用缓存）
    context.read<InsightBloc>().add(const InsightLoadCurrentWeek());
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  /// 强制刷新洞察
  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshController.repeat();
    context.read<InsightBloc>().add(const InsightGenerateCurrentWeek());
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      body: BlocListener<InsightBloc, InsightState>(
        listener: (context, state) {
          if (_isRefreshing &&
              (state.status == InsightStatus.success || state.status == InsightStatus.error)) {
            _refreshController.stop();
            if (mounted) {
              setState(() => _isRefreshing = false);
            }
          }
        },
        child: BlocBuilder<InsightBloc, InsightState>(
        builder: (context, state) {
          if ((state.status == InsightStatus.loading ||
              state.status == InsightStatus.generating) &&
              state.currentReport == null) {
            return _buildLoadingState(state.progressMessage);
          }

          if (state.status == InsightStatus.error || state.currentReport == null) {
            return _buildEmptyState(state.errorMessage);
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFFC4A57B),
            backgroundColor: Colors.white,
            child: _buildInsightContent(context, state.currentReport!, state.lastFetchTime),
          );
        },
      ),
      ),
    );
  }

  /// 加载状态
  Widget _buildLoadingState(String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message ?? '正在生成洞察...',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF8B7D6B),
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(String? errorMessage) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EBE0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  size: 40,
                  color: Color(0xFFD4C4B0),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '本周没有足够的内容生成洞察',
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF5D4E3C),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '记录更多内容后将自动生成',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB8ADA0),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () {
                  context.read<InsightBloc>().add(const InsightGenerateCurrentWeek());
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF5EBE0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  '重新生成',
                  style: TextStyle(
                    color: Color(0xFF5D4E3C),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 洞察内容
  Widget _buildInsightContent(BuildContext context, InsightReport report, DateTime? lastFetchTime) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 顶部标题
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatWeekRange(report.weekRange),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB8ADA0),
                        ),
                      ),
                      // 刷新按钮和更新时间
                      Row(
                        children: [
                          if (lastFetchTime != null)
                            Text(
                              _formatLastFetchTime(lastFetchTime),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB8ADA0),
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _onRefresh,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5EBE0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: AnimatedBuilder(
                                animation: _refreshController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: _refreshController.value * 6.283185307,
                                    child: child,
                                  );
                                },
                                child: const Icon(
                                  Icons.refresh,
                                  size: 18,
                                  color: Color(0xFFC4A57B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report.reportType,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D4E3C),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryReportsScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '查看历史报告',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B7D6B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 情绪概览
        SliverToBoxAdapter(
          child: _buildEmotionOverviewCard(report.emotionOverview),
        ),

        // 高频情境
        if (report.highFrequencyEmotions.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildHighFrequencySection(report.highFrequencyEmotions),
          ),

        // 潜在需求
        SliverToBoxAdapter(
          child: _buildPatternHypothesisCard(report.patternHypothesis),
        ),

        // 行动建议
        if (report.actionSuggestions.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildActionSuggestionsSection(report.actionSuggestions),
          ),

        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  /// 情绪概览卡片
  Widget _buildEmotionOverviewCard(EmotionOverview overview) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_emotions_outlined,
                  size: 18,
                  color: Color(0xFFC4A57B),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '情绪概览',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            overview.summary,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Color(0xFF5D4E3C),
            ),
          ),
        ],
      ),
    );
  }

  /// 高频情境列表
  Widget _buildHighFrequencySection(List<HighFrequencyEmotion> emotions) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.format_quote,
                  size: 18,
                  color: Color(0xFF6B9080),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '高频情境',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...emotions.map((emotion) => _buildEmotionItem(emotion)),
        ],
      ),
    );
  }

  /// 单个情境项
  Widget _buildEmotionItem(HighFrequencyEmotion emotion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${emotion.content}"',
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF5D4E3C),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: Color(0xFFB8ADA0),
              ),
              const SizedBox(width: 4),
              Text(
                emotion.time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB8ADA0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 潜在需求卡片
  Widget _buildPatternHypothesisCard(PatternHypothesis pattern) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E7),
            Color(0xFFFFF5E0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC4A57B).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: Color(0xFFC4A57B),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '潜在需求',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHighlightedText(pattern),
        ],
      ),
    );
  }

  /// 构建高亮文本
  Widget _buildHighlightedText(PatternHypothesis pattern) {
    // 解析模板文本并替换高亮标签
    String text = pattern.text;

    // 创建高亮标签映射
    final tagMap = <String, String>{};
    for (final tag in pattern.highlightTags) {
      tagMap[tag.key] = tag.value;
    }

    // 构建 TextSpan 列表
    final spans = <TextSpan>[];
    final regex = RegExp(r'\{(\w+)\}');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // 添加普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 15,
            height: 1.8,
            color: Color(0xFF5D4E3C),
          ),
        ));
      }

      // 添加高亮文本
      final key = match.group(1);
      final value = tagMap[key] ?? '{$key}';
      spans.add(TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 15,
          height: 1.8,
          color: key == 'trigger' ? const Color(0xFFE07B3E) : const Color(0xFF8B5CF6),
          fontWeight: FontWeight.w600,
        ),
      ));

      lastEnd = match.end;
    }

    // 添加剩余文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 15,
          height: 1.8,
          color: Color(0xFF5D4E3C),
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// 行动建议
  Widget _buildActionSuggestionsSection(List<ActionSuggestion> suggestions) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: Color(0xFF4A90A4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '行动建议',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
        ],
      ),
    );
  }

  /// 单个建议项
  Widget _buildSuggestionItem(ActionSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4E3C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF8B7D6B),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化周范围
  String _formatWeekRange(String weekRange) {
    // weekRange 格式: "2026-01-27 ~ 2026-02-02"
    final parts = weekRange.split(' ~ ');
    if (parts.length == 2) {
      try {
        final start = DateTime.parse(parts[0]);
        final end = DateTime.parse(parts[1]);
        final startFormatted = DateFormat('M月d日').format(start);
        final endFormatted = DateFormat('M月d日').format(end);
        return '$startFormatted - $endFormatted';
      } catch (e) {
        return weekRange;
      }
    }
    return weekRange;
  }

  /// 格式化最后更新时间
  String _formatLastFetchTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚更新';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return DateFormat('M/d HH:mm').format(time);
    }
  }
}
