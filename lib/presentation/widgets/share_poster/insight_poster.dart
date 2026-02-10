/// 周洞察海报
/// 用于分享周洞察报告
library;

import 'package:flutter/material.dart';
import '../../../domain/entities/insight_report.dart';
import '../../../core/theme/poster_colors.dart';

class InsightPoster extends StatelessWidget {
  final InsightReport report;
  final bool isDarkMode;

  const InsightPoster({
    super.key,
    required this.report,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = isDarkMode
        ? PosterColors.getDarkScheme(PosterColors.neutral)
        : PosterColors.neutral;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1E1C) : const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部装饰条
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.accent.withOpacity(0.3),
                  colorScheme.accent,
                  colorScheme.accent.withOpacity(0.3),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：标题和日期
                _buildHeader(colorScheme),

                const SizedBox(height: 24),

                // 情绪概览
                _buildEmotionOverview(colorScheme),

                const SizedBox(height: 20),

                // 高频情绪
                if (report.highFrequencyEmotions.isNotEmpty) ...[
                  _buildHighFrequencyEmotions(colorScheme),
                  const SizedBox(height: 20),
                ],

                // 模式洞察
                _buildPatternInsight(colorScheme),

                const SizedBox(height: 20),

                // 行动建议
                if (report.actionSuggestions.isNotEmpty)
                  _buildActionSuggestion(colorScheme),

                const SizedBox(height: 24),

                // 品牌信息
                _buildBranding(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '周洞察',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colorScheme.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${report.recordCount}条记录',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          report.weekRange,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionOverview(PosterColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 18,
                color: colorScheme.accent,
              ),
              const SizedBox(width: 8),
              Text(
                '情绪画像',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.emotionOverview.summary,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.textPrimary,
              height: 1.6,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHighFrequencyEmotions(PosterColorScheme colorScheme) {
    final topEmotions = report.highFrequencyEmotions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '高频情绪',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topEmotions.map((emotion) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                emotion.content,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPatternInsight(PosterColorScheme colorScheme) {
    // 解析 patternHypothesis 中的 <highlight> 标签
    final pattern = report.patternHypothesis.text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.accent.withOpacity(0.1),
            colorScheme.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: colorScheme.accent,
              ),
              const SizedBox(width: 8),
              Text(
                '模式洞察',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _cleanHighlightTags(pattern),
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.textPrimary,
              height: 1.6,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSuggestion(PosterColorScheme colorScheme) {
    final suggestion = report.actionSuggestions.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 16,
              color: colorScheme.accent,
            ),
            const SizedBox(width: 6),
            Text(
              '行动建议',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorScheme.accent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            suggestion.content,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.textPrimary,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBranding(PosterColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '瞬',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '瞬记',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '看见情绪的纹理',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.textSecondary.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  String _cleanHighlightTags(String text) {
    return text
        .replaceAll('<highlight>', '')
        .replaceAll('</highlight>', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
