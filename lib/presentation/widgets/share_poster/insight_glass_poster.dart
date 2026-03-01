/// 洞察周报 - 玻璃拟态风格
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../domain/entities/insight_report.dart';
import '../../../core/theme/poster_colors.dart';

class InsightGlassPoster extends StatelessWidget {
  final InsightReport report;
  final bool isDarkMode;

  const InsightGlassPoster({
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1B1B1F),
                  const Color(0xFF0F1012),
                ]
              : [
                  const Color(0xFFF7F2EA),
                  const Color(0xFFEAF1F6),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.white)
                    .withOpacity(isDarkMode ? 0.08 : 0.22),
                border: Border.all(
                  color: Colors.white.withOpacity(isDarkMode ? 0.12 : 0.35),
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '周洞察',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${report.recordCount ?? 0}条记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.weekRange,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 12),

                  if (report.patternHypothesis.text.isNotEmpty) ...[
                    _sectionTitle('PATTERN', colorScheme),
                    const SizedBox(height: 8),
                    Text(
                      report.patternHypothesis.text,
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

                  if (report.actionSuggestions.isNotEmpty) ...[
                    _sectionTitle('ACTION', colorScheme),
                    const SizedBox(height: 6),
                    Text(
                      report.actionSuggestions.first.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.textPrimary,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

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
                        'GLASS',
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
          ),
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
