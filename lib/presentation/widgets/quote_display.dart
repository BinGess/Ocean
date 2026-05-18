import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../domain/entities/quote.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

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
  int _displayIndex = 0; // 实际显示的索引
  Timer? _autoSwitchTimer;
  bool _isAnimating = false;
  bool _isFadingOut = true; // 区分淡出/淡入阶段

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
    _autoSwitchTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
      final l10n = AppLocalizations.of(context) ??
          AppLocalizations(Localizations.localeOf(context));
      return Center(
        child: Text(
          l10n.quoteEmptyData,
          style: AppTypography.recordHint.copyWith(
            letterSpacing: 0.3,
            color: const Color(0xFF8F7760),
          ),
        ),
      );
    }

    final displayQuote = widget.quotes[_displayIndex];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _switchQuote,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AnimatedBuilder(
              animation: _transitionAnimation,
              builder: (context, child) {
                return _buildQuoteContent(displayQuote);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建文案内容容器
  Widget _buildQuoteContent(Quote quote) {
    final progress = _transitionAnimation.value;

    // 淡出阶段：progress 0→1，opacity 1→0，blur 0→6，scale 1→1.02
    // 淡入阶段：progress 1→0，opacity 0→1，blur 6→0，scale 0.98→1

    final double opacity;
    final double blur;
    final double scale;
    const maxBlur = 6.0;

    if (_isFadingOut) {
      // 淡出：progress从0到1
      opacity = 1.0 - progress; // 1.0 → 0.0
      blur = progress * maxBlur; // 0.0 → 6.0
      scale = 1.0 + (progress * 0.02); // 1.0 → 1.02
    } else {
      // 淡入：progress从1到0
      opacity = 1.0 - progress; // 0.0 → 1.0
      blur = progress * maxBlur; // 6.0 → 0.0
      scale = 0.98 + ((1.0 - progress) * 0.02); // 0.98 → 1.0
    }

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blur.clamp(0.0, maxBlur),
            sigmaY: blur.clamp(0.0, maxBlur),
          ),
          child: _buildQuoteText(quote),
        ),
      ),
    );
  }

  /// 构建文案和作者文本
  Widget _buildQuoteText(Quote quote) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final displayContent = quote.localizedContent(languageCode);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 主文案（衬线字体）
        Text(
          displayContent,
          textAlign: TextAlign.center,
          style: AppTypography.quoteBody,
        ),
        const SizedBox(height: 12),
        Container(
          width: 74,
          height: 1,
          color: const Color(0xFFE4D3BD).withValues(alpha: 0.9),
        ),
        const SizedBox(height: 10),
        // 作者信息（无衬线字体）
        Text(
          quote.author,
          textAlign: TextAlign.center,
          style: AppTypography.quoteAuthor,
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
