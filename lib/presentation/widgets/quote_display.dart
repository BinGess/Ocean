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
  int _displayIndex = 0;  // 实际显示的索引
  Timer? _autoSwitchTimer;
  bool _isAnimating = false;
  bool _isFadingOut = true;  // 区分淡出/淡入阶段

  @override
  void initState() {
    super.initState();

    // 动画控制器：每个阶段1秒，总共2秒
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 过渡动画曲线
    _transitionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 启动自动切换（3秒）
    _startAutoSwitch();
  }

  void _startAutoSwitch() {
    _autoSwitchTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isAnimating) {
        _switchQuote();
      }
    });
  }

  /// 切换文案 - 执行 fade-out → 改变index → fade-in
  Future<void> _switchQuote() async {
    if (_isAnimating || widget.quotes.isEmpty) return;
    _isAnimating = true;

    // 计算下一个索引
    _currentIndex = (_currentIndex + 1) % widget.quotes.length;

    // 阶段1：淡出当前文案（1秒）
    _isFadingOut = true;
    await _animationController.forward();

    // 切换显示的文案索引
    if (mounted) {
      setState(() {
        _displayIndex = _currentIndex;
      });
    }

    // 阶段2：淡入新文案（1秒）
    _isFadingOut = false;
    await _animationController.reverse();

    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotes.isEmpty) {
      return const Center(child: Text('暂无文案数据'));
    }

    final displayQuote = widget.quotes[_displayIndex];

    return GestureDetector(
      onTap: _switchQuote,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AnimatedBuilder(
            animation: _transitionAnimation,
            builder: (context, child) {
              return _buildQuoteContent(displayQuote);
            },
          ),
        ),
      ),
    );
  }

  /// 构建文案内容容器
  Widget _buildQuoteContent(Quote quote) {
    final progress = _transitionAnimation.value;

    // 淡出阶段：progress 0→1，opacity 1→0，blur 0→10，scale 1→1.02
    // 淡入阶段：progress 1→0，opacity 0→1，blur 10→0，scale 0.98→1

    final double opacity;
    final double blur;
    final double scale;

    if (_isFadingOut) {
      // 淡出：progress从0到1
      opacity = 1.0 - progress;           // 1.0 → 0.0
      blur = progress * 10.0;             // 0.0 → 10.0
      scale = 1.0 + (progress * 0.02);    // 1.0 → 1.02
    } else {
      // 淡入：progress从1到0
      opacity = 1.0 - progress;           // 0.0 → 1.0
      blur = progress * 10.0;             // 10.0 → 0.0
      scale = 0.98 + ((1.0 - progress) * 0.02);  // 0.98 → 1.0
    }

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blur.clamp(0.0, 10.0),
            sigmaY: blur.clamp(0.0, 10.0),
          ),
          child: _buildQuoteText(quote),
        ),
      ),
    );
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
