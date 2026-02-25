import 'package:flutter/material.dart';
import '../../domain/entities/quote.dart';

class QuoteCard extends StatefulWidget {
  final Quote quote;
  final VoidCallback onNext;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.onNext,
  });

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();

    // 呼吸动效控制器（3s周期）
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 呼吸曲线：opacity 0.7 -> 1.0 -> 0.7
    _breathingAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
  }

  String _categoryLabel(QuoteCategory category) {
    return {
      QuoteCategory.mindfulness: '正念',
      QuoteCategory.selfCompassion: '自我同情',
      QuoteCategory.stoicism: '斯多葛派',
      QuoteCategory.nvc: 'NVC',
    }[category]!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onNext,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 主文案（衬线字体）- 带呼吸动效
            FadeTransition(
              opacity: _breathingAnimation,
              child: Text(
                widget.quote.content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.8,
                  fontFamily: 'Georgia',  // 衬线字体
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5D4E3C),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 作者信息（无衬线字体）- 保持不动
            Text(
              '— ${widget.quote.author}',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Helvetica',  // 无衬线字体
                fontWeight: FontWeight.w500,
                color: Color(0xFFA89F97),
                letterSpacing: 2.0,
              ),
            ),

            const SizedBox(height: 48),

            // 分类标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _categoryLabel(widget.quote.category),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFC4A57B),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 提示：点击切换
            Text(
              '点击文案切换 →',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }
}
