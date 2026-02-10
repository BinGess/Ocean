/// 瑞士极简风格海报
/// 高对比、严格间距、理性网格
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/poster_colors.dart';
import 'poster_data.dart';

class SwissMinimalPoster extends StatelessWidget {
  final PosterData data;
  final bool isDarkMode;

  const SwissMinimalPoster({
    super.key,
    required this.data,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final lightScheme = PosterColors.getSchemeForEmotions(data.emotions);
    final colorScheme = isDarkMode
        ? PosterColors.getDarkScheme(lightScheme)
        : lightScheme;

    final dateFormat = DateFormat('yyyy.MM.dd');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      width: 340,
      height: 520,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0E0E0E) : const Color(0xFFF9F9F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.cardBorder.withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                  dateFormat.format(data.dateTime),
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
              color: colorScheme.textPrimary.withOpacity(0.12),
            ),
            const SizedBox(height: 18),

            // Main title
            Text(
              data.mainFeeling ?? '记录',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.5,
                height: 1.0,
                color: colorScheme.textPrimary,
              ),
            ),

            const SizedBox(height: 10),
            Text(
              data.emotions.isNotEmpty
                  ? data.emotions.take(4).join(' · ')
                  : '情绪轨迹',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.textSecondary,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 18),

            // Body
            Text(
              data.transcription,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.textPrimary,
                height: 1.7,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),

            const Spacer(),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeFormat.format(data.dateTime),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'MINIMAL GRID',
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
}
