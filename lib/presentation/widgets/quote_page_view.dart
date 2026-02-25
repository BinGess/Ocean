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
        // 文案PageView
        PageView.builder(
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

        // 水纹淡出效果
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RipplePainter(
                    progress: _rippleAnimation.value,
                  ),
                );
              },
            ),
          ),
        ),

        // 页码指示器
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.quotes.length,
              (index) => Container(
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
          ),
        ),
      ],
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

class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.5) {
      // 前半段：模糊+缩放
      final blur = progress * 20;  // 0-10px blur

      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      );
      canvas.restore();
    } else {
      // 后半段：淡出
      final alpha = (1 - progress) * 0.3;  // 0.3-0
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withOpacity(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
