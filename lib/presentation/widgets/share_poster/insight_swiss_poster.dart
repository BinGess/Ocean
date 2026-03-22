/// 洞察周报 - 瑞士极简风格
library;

import 'package:flutter/material.dart';
import '../../../domain/entities/insight_report.dart';
import '../../../core/theme/poster_colors.dart';

class InsightSwissPoster extends StatelessWidget {
  final InsightReport report;
  final bool isDarkMode;

  const InsightSwissPoster({
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
        color: isDarkMode ? const Color(0xFF0E0E0E) : const Color(0xFFF9F9F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.cardBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '瞬记',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: colorScheme.textPrimary,
                  ),
                ),
                Text(
                  '${report.recordCount ?? 0}条记录',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: colorScheme.textPrimary.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 18),

            Text(
              '周洞察',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                letterSpacing: -1,
                height: 1.0,
                color: colorScheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              report.weekRange,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.textSecondary,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 16),

            _sectionTitle('OVERVIEW', colorScheme),
            const SizedBox(height: 8),
            Text(
              report.emotionOverview.summary,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.textPrimary,
                height: 1.65,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 14),

            if (report.actionSuggestions.isNotEmpty) ...[
              _sectionTitle('ACTION', colorScheme),
              const SizedBox(height: 8),
              Text(
                report.actionSuggestions.first.content,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.textPrimary,
                  height: 1.55,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const Spacer(),

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
                  'SWISS GRID',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, PosterColorScheme colorScheme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        color: colorScheme.textSecondary,
        letterSpacing: 3,
      ),
    );
  }
}
