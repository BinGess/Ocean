import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../domain/entities/quote.dart';

/// 简洁的文案展示组件 - 仅显示文案内容和作者，不显示标签/指示器/提示
class QuoteDisplay extends StatefulWidget {
  final List<Quote> quotes;

  const QuoteDisplay({
    super.key,
    required this.quotes,
  });

  @override
  State<QuoteDisplay> createState() => _QuoteDisplayState();
}

class _QuoteDisplayState extends State<QuoteDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _transitionAnimation;

  int _currentIndex = 0;
  Timer? _autoSwitchTimer;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    // 动画控制器：用于切换过渡（3秒总时间）
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // 过渡动画曲线
    _transitionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 启动自动切换（12秒）
    _startAutoSwitch();
  }

  void _startAutoSwitch() {
    _autoSwitchTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && !_isAnimating) {
        _switchQuote();
      }
    });
  }

  /// 切换文案 - 执行 fade-out → 改变index → fade-in
  Future<void> _switchQuote() async {
    if (_isAnimating) return;
    _isAnimating = true;

    // 前1.5秒：淡出并模糊
    await _animationController.forward();

    // 改变索引
    if (mounted) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.quotes.length;
      });
    }

    // 重置并反向运行（后1.5秒：淡入并清晰）
    _animationController.reverse();

    // 等待动画完成
    await _animationController.forward();
    _animationController.reset();

    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotes.isEmpty) {
      return const Center(child: Text('暂无文案数据'));
    }

    final currentQuote = widget.quotes[_currentIndex];

    return GestureDetector(
      onTap: _switchQuote,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _transitionAnimation,
            builder: (context, child) {
              return _buildQuoteContent(currentQuote);
            },
          ),
        ),
      ),
    );
  }

  /// 构建文案内容容器
  Widget _buildQuoteContent(Quote quote) {
    final progress = _transitionAnimation.value;

    // 第一阶段（0-0.5）：淡出 + 模糊 + 微放大
    // 第二阶段（0.5-1.0）：淡入 + 清晰 + 回正
    if (progress < 0.5) {
      // 淡出阶段（0 -> 1）
      final fadeProgress = progress * 2;
      final opacity = 1.0 - fadeProgress; // 1.0 -> 0.0
      final blur = fadeProgress * 10.0;    // 0.0 -> 10.0px
      final scale = 1.0 + (fadeProgress * 0.02); // 1.0 -> 1.02

      return Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: _buildQuoteText(quote),
          ),
        ),
      );
    } else {
      // 淡入阶段（0 -> 1）
      final fadeProgress = (progress - 0.5) * 2;
      final opacity = fadeProgress;           // 0.0 -> 1.0
      final blur = (1.0 - fadeProgress) * 10.0; // 10.0 -> 0.0px
      final scale = 0.98 + (fadeProgress * 0.02); // 0.98 -> 1.0

      return Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: _buildQuoteText(quote),
          ),
        ),
      );
    }
  }

  /// 构建文案和作者文本
  Widget _buildQuoteText(Quote quote) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 主文案（衬线字体）
        Text(
          quote.content,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            height: 1.8,
            fontFamily: 'Georgia',
            color: Color(0xFF5D4E3C),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 20),
        // 作者信息（无衬线字体）
        Text(
          '— ${quote.author} —',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Helvetica',
            color: Color(0xFF999999),
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoSwitchTimer?.cancel();
    super.dispose();
  }
}
