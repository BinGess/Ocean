import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../domain/entities/quote.dart';
import 'quote_card.dart';

class QuotePageView extends StatefulWidget {
  final List<Quote> quotes;
  final Duration autoSwitchDuration;

  const QuotePageView({
    super.key,
    required this.quotes,
    this.autoSwitchDuration = const Duration(seconds: 12),
  });

  @override
  State<QuotePageView> createState() => _QuotePageViewState();
}

class _QuotePageViewState extends State<QuotePageView>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  Timer? _autoSwitchTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // 水纹淡出动效（1.5s）
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rippleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    // 启动自动切换（12s）
    _startAutoSwitch();
  }

  void _startAutoSwitch() {
    _autoSwitchTimer = Timer.periodic(widget.autoSwitchDuration, (_) {
      if (mounted) {
        if (_currentIndex < widget.quotes.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        } else {
          _pageController.jumpToPage(0);  // 循环回到开始
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 文案PageView（优化：使用RepaintBoundary）
        RepaintBoundary(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              // 触发水纹淡出效果
              _rippleController.forward(from: 0);
            },
            itemCount: widget.quotes.length,
            itemBuilder: (context, index) {
              return QuoteCard(
                quote: widget.quotes[index],
                onNext: () {
                  if (index < widget.quotes.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _pageController.jumpToPage(0);
                  }
                },
              );
            },
          ),
        ),

        // 水纹淡出效果（优化：使用RepaintBoundary）
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, child) {
                  return _buildRippleEffect();
                },
              ),
            ),
          ),
        ),

        // 页码指示器（优化：提取为单独方法）
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: _buildPageIndicator(),
        ),
      ],
    );
  }

  /// 构建水纹效果（优化：改进视觉呈现）
  Widget _buildRippleEffect() {
    final progress = _rippleAnimation.value;

    if (progress < 0.5) {
      // 前半段：模糊效果（0-1.5s）
      final normalizedProgress = progress * 2;  // 0 to 1
      final blur = normalizedProgress * 15;  // 0-15px blur，更平滑
      return CustomPaint(
        painter: _RipplePainter(
          progress: progress,
          blur: blur,
          isBlurPhase: true,
        ),
      );
    } else {
      // 后半段：淡出（1.5-3s）
      final normalizedProgress = (progress - 0.5) * 2;  // 0 to 1
      final alpha = (1 - normalizedProgress) * 0.25;  // 0.25-0，更柔和
      return CustomPaint(
        painter: _RipplePainter(
          progress: progress,
          alpha: alpha,
          isBlurPhase: false,
        ),
      );
    }
  }

  /// 构建页码指示器
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.quotes.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentIndex == index
                ? const Color(0xFFC4A57B)
                : const Color(0xFFE8DCC8),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rippleController.dispose();
    _autoSwitchTimer?.cancel();
    super.dispose();
  }
}

/// 水纹淡出动效绘制器（优化版）
class _RipplePainter extends CustomPainter {
  final double progress;
  final double alpha;
  final double blur;
  final bool isBlurPhase;

  const _RipplePainter({
    required this.progress,
    this.alpha = 0.0,
    this.blur = 0.0,
    this.isBlurPhase = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isBlurPhase) {
      // 前半段：模糊效果，从0.05渐进到0.15不透明度
      final opacity = 0.05 + (blur / 15) * 0.1;  // 0.05-0.15
      if (blur > 0.5) {
        final paint = Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          paint,
        );
      }
    } else {
      // 后半段：白色淡出，更平滑的渐隐效果
      if (alpha > 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.white.withOpacity(alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.alpha != alpha ||
        oldDelegate.blur != blur ||
        oldDelegate.isBlurPhase != isBlurPhase;
  }
}
