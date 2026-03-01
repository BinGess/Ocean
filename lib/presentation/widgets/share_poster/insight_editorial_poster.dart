/// 周洞察海报 - 杂志风格
/// 极简排版，大字号对比，知性风格
library;

import 'package:flutter/material.dart';
import '../../../domain/entities/insight_report.dart';
import '../../../core/theme/poster_colors.dart';

class InsightEditorialPoster extends StatelessWidget {
  final InsightReport report;
  final bool isDarkMode;

  const InsightEditorialPoster({
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
      height: 520,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 网格装饰
          if (!isDarkMode) _buildGridOverlay(colorScheme),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 杂志头部
                _buildMagazineHeader(colorScheme),

                const SizedBox(height: 20),

                Container(
                  height: 1,
                  color: colorScheme.textPrimary.withOpacity(0.1),
                ),

                const SizedBox(height: 20),

                // 主标题 - 周洞察
                _buildMainTitle(colorScheme),

                const SizedBox(height: 24),

                // 情绪概览摘要
                Expanded(
                  child: _buildContent(colorScheme),
                ),

                // 底部
                _buildFooter(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridOverlay(PosterColorScheme colorScheme) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPainter(
          color: colorScheme.cardBorder.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildMagazineHeader(PosterColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '瞬记',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.textPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'WEEKLY INSIGHT',
              style: TextStyle(
                fontSize: 8,
                color: colorScheme.textSecondary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.textPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '${report.recordCount ?? 0}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'RECORDS',
              style: TextStyle(
                fontSize: 8,
                color: colorScheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainTitle(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '周洞察',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w200,
            color: colorScheme.textPrimary,
            height: 1.0,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 20,
              height: 2,
              color: colorScheme.accent,
            ),
            const SizedBox(width: 12),
            Text(
              report.weekRange,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 情绪概览
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorScheme.accent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OVERVIEW',
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.textSecondary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                report.emotionOverview.summary,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.textPrimary,
                  height: 1.65,
                ),
                strutStyle: const StrutStyle(
                  height: 1.65,
                  forceStrutHeight: true,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: true,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const Spacer(),

        // 行动建议
        if (report.actionSuggestions.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.textPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'ACTION',
                  style: TextStyle(
                    fontSize: 8,
                    color: isDarkMode ? Colors.black : Colors.white,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.actionSuggestions.first.content,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.textPrimary,
              height: 1.55,
            ),
            strutStyle: const StrutStyle(
              height: 1.55,
              forceStrutHeight: true,
            ),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: true,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(PosterColorScheme colorScheme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: colorScheme.textPrimary.withOpacity(0.1),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              report.reportType,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.textSecondary,
              ),
            ),
            Text(
              '看见情绪的纹理',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const margin = 24.0;
    const dotSize = 3.0;

    final positions = [
      const Offset(margin, margin),
      Offset(size.width - margin, margin),
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
    ];

    for (final pos in positions) {
      canvas.drawLine(
        Offset(pos.dx - dotSize, pos.dy),
        Offset(pos.dx + dotSize, pos.dy),
        paint,
      );
      canvas.drawLine(
        Offset(pos.dx, pos.dy - dotSize),
        Offset(pos.dx, pos.dy + dotSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
