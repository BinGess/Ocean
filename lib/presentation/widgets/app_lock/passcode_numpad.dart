/// 密码输入键盘组件
/// 极简风格的数字键盘，带有触觉反馈
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PasscodeNumpad extends StatelessWidget {
  /// 数字点击回调
  final void Function(String digit) onDigitPressed;

  /// 删除回调
  final VoidCallback onDeletePressed;

  /// 生物识别按钮回调（可选）
  final VoidCallback? onBiometricPressed;

  /// 生物识别图标（可选）
  final IconData? biometricIcon;

  const PasscodeNumpad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onBiometricPressed,
    this.biometricIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 第一行：1 2 3
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 16),
        // 第二行：4 5 6
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 16),
        // 第三行：7 8 9
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 16),
        // 第四行：生物识别/空 0 删除
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _NumpadButton(
            digit: digit,
            onPressed: () => onDigitPressed(digit),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 左侧：生物识别或空白
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: onBiometricPressed != null
              ? _NumpadIconButton(
                  icon: biometricIcon ?? Icons.fingerprint,
                  onPressed: onBiometricPressed!,
                )
              : const SizedBox(width: 72, height: 72),
        ),
        // 中间：0
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _NumpadButton(
            digit: '0',
            onPressed: () => onDigitPressed('0'),
          ),
        ),
        // 右侧：删除
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _NumpadIconButton(
            icon: Icons.backspace_outlined,
            onPressed: onDeletePressed,
          ),
        ),
      ],
    );
  }
}

/// 数字按钮
class _NumpadButton extends StatefulWidget {
  final String digit;
  final VoidCallback onPressed;

  const _NumpadButton({
    required this.digit,
    required this.onPressed,
  });

  @override
  State<_NumpadButton> createState() => _NumpadButtonState();
}

class _NumpadButtonState extends State<_NumpadButton> {
  bool _isPressed = false;

  void _triggerHaptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // 某些设备可能不支持触觉反馈
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _triggerHaptic();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _isPressed
              ? const Color(0xFFE8DED0)
              : const Color(0xFFF5EBE0),
          shape: BoxShape.circle,
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            widget.digit,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: _isPressed
                  ? const Color(0xFF5D4E3C)
                  : const Color(0xFF5D4E3C),
            ),
          ),
        ),
      ),
    );
  }
}

/// 图标按钮（删除/生物识别）
class _NumpadIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NumpadIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_NumpadIconButton> createState() => _NumpadIconButtonState();
}

class _NumpadIconButtonState extends State<_NumpadIconButton> {
  bool _isPressed = false;

  void _triggerHaptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // 某些设备可能不支持触觉反馈
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _triggerHaptic();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _isPressed
              ? const Color(0xFFE8DED0).withOpacity(0.5)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: 28,
            color: _isPressed
                ? const Color(0xFF5D4E3C)
                : const Color(0xFF8B7D6B),
          ),
        ),
      ),
    );
  }
}
