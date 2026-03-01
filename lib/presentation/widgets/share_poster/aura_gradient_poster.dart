/// 情绪光晕风格海报
/// 柔和的弥散光斑渐变，搭配磨砂玻璃效果
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/poster_colors.dart';
import 'poster_data.dart';

class AuraGradientPoster extends StatelessWidget {
  final PosterData data;
  final bool isDarkMode;

  const AuraGradientPoster({
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

    return Container(
      width: 340,
      height: 520,
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
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期时间
                  _buildDateTime(colorScheme),

                  const Spacer(flex: 2),

                  // 主要情绪词（磨砂玻璃卡片）
                  _buildMainEmotionCard(colorScheme),

                  const SizedBox(height: 20),

                  // NVC 连接桥梁
                  if (data.mainFeeling != null && data.mainNeed != null)
                    _buildBridge(colorScheme),

                  const Spacer(flex: 3),

                  // AI 洞察（底部）
                  if (data.insight != null)
                    _buildInsightCapsule(colorScheme),

                  const SizedBox(height: 16),

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
            colorScheme.backgroundStart.withOpacity(0.8),
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
          top: -60,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.accent.withOpacity(0.4),
                  colorScheme.accent.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 次光斑（左下）
        Positioned(
          bottom: -80,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.backgroundEnd.withOpacity(0.6),
                  colorScheme.backgroundEnd.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 小光斑（中间）
        Positioned(
          top: 180,
          right: 60,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.accent.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTime(PosterColorScheme colorScheme) {
    final dateFormat = DateFormat('M月d日');
    final weekday = _getWeekdayName(data.dateTime.weekday);
    final timeFormat = DateFormat('HH:mm');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${dateFormat.format(data.dateTime)} $weekday',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          timeFormat.format(data.dateTime),
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMainEmotionCard(PosterColorScheme colorScheme) {
    final mainFeeling = data.mainFeeling ?? '觉察';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: colorScheme.cardBackground.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.cardBorder.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '此刻的感受',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                mainFeeling,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  color: colorScheme.textPrimary,
                  letterSpacing: 8,
                  height: 1.2,
                ),
              ),
              if (data.emotions.length > 1) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: data.emotions.skip(1).take(3).map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      e,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.textPrimary.withOpacity(0.8),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBridge(PosterColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            '因为',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.accent.withOpacity(0.1),
                    colorScheme.accent.withOpacity(0.5),
                    colorScheme.accent.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '渴望${data.mainNeed}',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCapsule(PosterColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.cardBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.cardBorder.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: colorScheme.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.insight!,
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

  String _getWeekdayName(int weekday) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[weekday - 1];
  }
}
