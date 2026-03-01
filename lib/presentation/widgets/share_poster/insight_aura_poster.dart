/// 周洞察海报 - 光晕渐变风格
/// 柔和的弥散光斑渐变，更有视觉冲击力
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../domain/entities/insight_report.dart';
import '../../../core/theme/poster_colors.dart';

class InsightAuraPoster extends StatelessWidget {
  final InsightReport report;
  final bool isDarkMode;

  const InsightAuraPoster({
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
      height: 560,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.accent.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 背景渐变层
            _buildGradientBackground(colorScheme),

            // 光斑装饰
            _buildAuraOrbs(colorScheme),

            // 内容层
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和日期
                  _buildHeader(colorScheme),

                  const SizedBox(height: 20),

                  // 核心洞察卡片
                  _buildMainInsightCard(colorScheme),

                  const Spacer(),

                  // 高频情绪
                  if (report.highFrequencyEmotions.isNotEmpty) ...[
                    _buildHighFrequencySection(colorScheme),
                    const SizedBox(height: 16),
                  ],

                  // 行动建议
                  if (report.actionSuggestions.isNotEmpty)
                    _buildActionCapsule(colorScheme),

                  const Spacer(),

                  // 品牌信息
                  _buildBranding(colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground(PosterColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.backgroundStart,
            colorScheme.backgroundEnd,
            colorScheme.backgroundStart.withOpacity(0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildAuraOrbs(PosterColorScheme colorScheme) {
    return Stack(
      children: [
        // 主光斑（右上）
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.accent.withOpacity(0.5),
                  colorScheme.accent.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 次光斑（左下）
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.backgroundEnd.withOpacity(0.7),
                  colorScheme.backgroundEnd.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 小光斑（中间）
        Positioned(
          top: 200,
          right: 40,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.accent.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(PosterColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '周洞察',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: colorScheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              report.weekRange,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.accent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${report.recordCount ?? 0}条记录',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainInsightCard(PosterColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.cardBackground.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.cardBorder.withOpacity(0.3),
              width: 1,
            ),
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
                  height: 1.7,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighFrequencySection(PosterColorScheme colorScheme) {
    final topEmotions = report.highFrequencyEmotions.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '高频情境',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        ...topEmotions.map((emotion) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colorScheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emotion.content,
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
          ),
        )),
      ],
    );
  }

  Widget _buildActionCapsule(PosterColorScheme colorScheme) {
    final suggestion = report.actionSuggestions.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.accent.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: colorScheme.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  suggestion.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.textPrimary,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
}
