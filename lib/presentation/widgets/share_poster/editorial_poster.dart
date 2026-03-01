/// 杂志封面风格海报
/// 极简排版，大字号对比，严格网格系统
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/poster_colors.dart';
import 'poster_data.dart';

class EditorialPoster extends StatelessWidget {
  final PosterData data;
  final bool isDarkMode;

  const EditorialPoster({
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
      height: 480,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(2),
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
          // 网格线装饰（可选，增加杂志感）
          if (!isDarkMode) _buildGridOverlay(colorScheme),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：期刊风格的头部
                _buildMagazineHeader(colorScheme),

                const SizedBox(height: 24),

                // 分割线
                Container(
                  height: 1,
                  color: colorScheme.textPrimary.withOpacity(0.1),
                ),

                const SizedBox(height: 24),

                // 主体：超大情绪词
                Expanded(
                  child: _buildMainContent(colorScheme),
                ),

                // 底部信息
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
    final dateFormat = DateFormat('yyyy');
    final monthDay = DateFormat('MM.dd');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：期号风格
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
              'MINDFLOW',
              style: TextStyle(
                fontSize: 8,
                color: colorScheme.textSecondary,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        const Spacer(),
        // 右侧：日期
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              dateFormat.format(data.dateTime),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.textSecondary,
                letterSpacing: 2,
              ),
            ),
            Text(
              monthDay.format(data.dateTime),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: colorScheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainContent(PosterColorScheme colorScheme) {
    final mainFeeling = data.mainFeeling ?? '觉察';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 超大情绪词（作为图形处理）
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            child: Text(
              mainFeeling,
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w200,
                color: colorScheme.textPrimary,
                height: 1.0,
                letterSpacing: -4,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 次要情绪词（小字）
        if (data.emotions.length > 1) ...[
          Row(
            children: [
              Container(
                width: 16,
                height: 1,
                color: colorScheme.accent,
              ),
              const SizedBox(width: 12),
              Text(
                data.emotions.skip(1).take(3).join(' · '),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // NVC 连接（从感受到需要）
        if (data.mainNeed != null) ...[
          _buildNVCConnection(colorScheme),
          const SizedBox(height: 20),
        ],

        // AI 洞察
        if (data.insight != null)
          _buildInsightBlock(colorScheme),

        const Spacer(),
      ],
    );
  }

  Widget _buildNVCConnection(PosterColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colorScheme.accent,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEED',
            style: TextStyle(
              fontSize: 9,
              color: colorScheme.textSecondary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.mainNeed!,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: colorScheme.textPrimary,
            ),
          ),
          if (data.nvcNeeds != null && data.nvcNeeds!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              data.nvcNeeds!.first.reason,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightBlock(PosterColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.textPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'INSIGHT',
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
          data.insight!,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.textPrimary,
            height: 1.6,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFooter(PosterColorScheme colorScheme) {
    final weekday = _getWeekdayName(data.dateTime.weekday);
    final timeFormat = DateFormat('HH:mm');

    return Column(
      children: [
        Container(
          height: 1,
          color: colorScheme.textPrimary.withOpacity(0.1),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$weekday ${timeFormat.format(data.dateTime)}',
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

  String _getWeekdayName(int weekday) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[weekday - 1];
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

    // 只绘制边框的网格点，保持简洁
    const margin = 28.0;
    const dotSize = 3.0;

    // 四个角落的网格点
    final positions = [
      const Offset(margin, margin),
      Offset(size.width - margin, margin),
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
    ];

    for (final pos in positions) {
      // 绘制小十字
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
