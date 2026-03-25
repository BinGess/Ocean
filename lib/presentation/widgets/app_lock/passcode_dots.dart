/// 密码圆点指示器
/// 显示已输入的密码位数
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PasscodeDots extends StatelessWidget {
  /// 密码总长度
  final int length;

  /// 已输入的位数
  final int filledCount;

  /// 是否显示错误状态
  final bool hasError;

  const PasscodeDots({
    super.key,
    required this.length,
    required this.filledCount,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isFilled ? 16 : 14,
          height: isFilled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? const Color(0xFFE57373)
                : (isFilled
                    ? AppColors.accent
                    : Colors.transparent),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFE57373)
                  : (isFilled
                      ? AppColors.accent
                      : AppColors.border),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

/// 带晃动动画的密码圆点
class ShakeablePasscodeDots extends StatefulWidget {
  final int length;
  final int filledCount;
  final bool hasError;

  const ShakeablePasscodeDots({
    super.key,
    required this.length,
    required this.filledCount,
    this.hasError = false,
  });

  @override
  State<ShakeablePasscodeDots> createState() => ShakeablePasscodeDotsState();
}

class ShakeablePasscodeDotsState extends State<ShakeablePasscodeDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  /// 触发晃动动画
  void shake() {
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: PasscodeDots(
        length: widget.length,
        filledCount: widget.filledCount,
        hasError: widget.hasError,
      ),
    );
  }
}
