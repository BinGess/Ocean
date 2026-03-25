/// 玻璃拟态海报
/// 轻透卡片 + 渐变背景
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/poster_colors.dart';
import 'poster_data.dart';

class GlassPoster extends StatelessWidget {
  final PosterData data;
  final bool isDarkMode;

  const GlassPoster({
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

    final dateFormat = DateFormat('MM.dd');

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
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 柔和光斑
          Positioned(
            top: 30,
            left: 20,
            child: _buildGlow(colorScheme.accent.withValues(alpha: 0.25)),
          ),
          Positioned(
            bottom: 40,
            right: 10,
            child: _buildGlow(colorScheme.textSecondary.withValues(alpha: 0.18)),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.white : Colors.white)
                        .withValues(alpha: isDarkMode ? 0.08 : 0.22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.35),
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
                            '瞬记',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: colorScheme.textPrimary,
                            ),
                          ),
                          Text(
                            dateFormat.format(data.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        data.mainFeeling ?? '记录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.2,
                          color: colorScheme.textPrimary,
                          height: 1.0,
                        ),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        data.emotions.isNotEmpty
                            ? data.emotions.take(3).join(' · ')
                            : '情绪回声',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        data.transcription,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.textPrimary,
                          height: 1.65,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const Spacer(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GLASS',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: colorScheme.textSecondary,
                            ),
                          ),
                          if (data.mainNeed != null)
                            Text(
                              data.mainNeed!,
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.textSecondary,
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
        ],
      ),
    );
  }

  Widget _buildGlow(Color color) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
