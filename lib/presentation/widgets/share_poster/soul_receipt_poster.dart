/// 心灵票据风格海报
/// 像便利店小票或博物馆门票的复古设计
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/poster_colors.dart';
import 'poster_data.dart';

class SoulReceiptPoster extends StatelessWidget {
  final PosterData data;
  final bool isDarkMode;

  const SoulReceiptPoster({
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
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部锯齿边缘
          _buildZigzagEdge(colorScheme, isTop: true),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：标题和日期
                _buildHeader(colorScheme),

                const SizedBox(height: 16),
                _buildDashedDivider(colorScheme),
                const SizedBox(height: 16),

                // 主体：情绪词（大字号）
                _buildMainEmotion(colorScheme),

                const SizedBox(height: 20),
                _buildDashedDivider(colorScheme),
                const SizedBox(height: 16),

                // NVC 分析部分
                if (data.observation != null || data.feelings != null) ...[
                  _buildNVCSection(colorScheme),
                  const SizedBox(height: 16),
                  _buildDashedDivider(colorScheme),
                  const SizedBox(height: 16),
                ],

                // 需要部分
                if (data.mainNeed != null) ...[
                  _buildNeedsSection(colorScheme),
                  const SizedBox(height: 16),
                  _buildDashedDivider(colorScheme),
                  const SizedBox(height: 16),
                ],

                // AI 洞察
                if (data.insight != null) ...[
                  _buildInsightSection(colorScheme),
                  const SizedBox(height: 16),
                  _buildDashedDivider(colorScheme),
                  const SizedBox(height: 16),
                ],

                // 底部：品牌信息
                _buildFooter(colorScheme),
              ],
            ),
          ),

          // 底部锯齿边缘
          _buildZigzagEdge(colorScheme, isTop: false),
        ],
      ),
    );
  }

  Widget _buildZigzagEdge(PosterColorScheme colorScheme, {required bool isTop}) {
    return SizedBox(
      height: 12,
      child: CustomPaint(
        size: const Size(340, 12),
        painter: _ZigzagPainter(
          color: colorScheme.cardBorder,
          isTop: isTop,
        ),
      ),
    );
  }

  Widget _buildHeader(PosterColorScheme colorScheme) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final timeFormat = DateFormat('HH:mm');
    final weekday = _getWeekdayName(data.dateTime.weekday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          '瞬 记',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.textPrimary,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MOMENT CAPTURE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: colorScheme.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        // 日期时间行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateFormat.format(data.dateTime),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.textSecondary,
              ),
            ),
            Text(
              weekday,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.textSecondary,
              ),
            ),
            Text(
              timeFormat.format(data.dateTime),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainEmotion(PosterColorScheme colorScheme) {
    final mainFeeling = data.mainFeeling ?? '觉察';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '# 此刻感受',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: colorScheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            mainFeeling,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: colorScheme.textPrimary,
              letterSpacing: 4,
            ),
          ),
        ),
        if (data.emotions.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: data.emotions.skip(1).take(3).map((e) => Text(
              e,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 14,
                color: colorScheme.textSecondary,
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildNVCSection(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '# 观察',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: colorScheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (data.observation != null)
          Text(
            data.observation!,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.textPrimary,
              height: 1.6,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildNeedsSection(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '# 内在需要',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: colorScheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '→',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: colorScheme.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.mainNeed!,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (data.nvcNeeds != null && data.nvcNeeds!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            data.nvcNeeds!.first.reason,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildInsightSection(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '# AI 建议',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: colorScheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            data.insight!,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.textPrimary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(PosterColorScheme colorScheme) {
    return Column(
      children: [
        // 条形码装饰
        SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(30, (i) => Container(
              width: i % 3 == 0 ? 3 : 2,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: colorScheme.textSecondary.withOpacity(0.3),
            )),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '「 瞬记 · 看见情绪的纹理 」',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedDivider(PosterColorScheme colorScheme) {
    return Row(
      children: List.generate(40, (i) => Expanded(
        child: Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: i % 2 == 0 ? colorScheme.cardBorder : Colors.transparent,
        ),
      )),
    );
  }

  String _getWeekdayName(int weekday) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[weekday - 1];
  }
}

class _ZigzagPainter extends CustomPainter {
  final Color color;
  final bool isTop;

  _ZigzagPainter({required this.color, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    const zigWidth = 10.0;
    final zigHeight = size.height;

    if (isTop) {
      path.moveTo(0, zigHeight);
      for (double x = 0; x < size.width; x += zigWidth) {
        path.lineTo(x + zigWidth / 2, 0);
        path.lineTo(x + zigWidth, zigHeight);
      }
    } else {
      path.moveTo(0, 0);
      for (double x = 0; x < size.width; x += zigWidth) {
        path.lineTo(x + zigWidth / 2, zigHeight);
        path.lineTo(x + zigWidth, 0);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
