/// 解锁界面
/// 用于验证用户身份后进入应用
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/di/injection.dart';
import '../../widgets/app_lock/passcode_numpad.dart';
import '../../widgets/app_lock/passcode_dots.dart';

class LockScreen extends StatefulWidget {
  /// 解锁成功后的回调
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _appLockService = getIt<AppLockService>();
  final _dotsKey = GlobalKey<ShakeablePasscodeDotsState>();

  String _passcode = '';
  bool _hasError = false;
  String _errorMessage = '';
  bool _isLockedOut = false;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _showBiometricButton = false;
  IconData _biometricIcon = Icons.fingerprint;

  // 密码长度
  final int _passcodeLength = 4;

  @override
  void initState() {
    super.initState();
    // 延迟初始化，确保 widget 完全渲染后再执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initLockScreen();
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLockScreen() async {
    try {
      // 检查是否被锁定
      await _checkLockout();

      if (!mounted) return;

      // 检查是否支持生物识别
      final biometricEnabled = await _appLockService.isBiometricEnabled;
      if (biometricEnabled && mounted) {
        final biometricName = await _appLockService.biometricName;
        if (mounted) {
          setState(() {
            _showBiometricButton = true;
            _biometricIcon = biometricName.contains('Face')
                ? Icons.face
                : Icons.fingerprint;
          });

          // 注意：不再自动触发生物识别，由用户手动点击
          // 这样可以避免在 release 版本中可能出现的问题
        }
      }
    } catch (e) {
      debugPrint('LockScreen: 初始化失败: $e');
    }
  }

  Future<void> _checkLockout() async {
    try {
      final isLockedOut = await _appLockService.isLockedOut;
      if (isLockedOut && mounted) {
        final seconds = await _appLockService.lockoutRemainingSeconds;
        if (mounted) {
          setState(() {
            _isLockedOut = true;
            _lockoutSeconds = seconds;
          });
          _startLockoutTimer();
        }
      }
    } catch (e) {
      debugPrint('LockScreen: 检查锁定状态失败: $e');
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds > 0) {
        setState(() {
          _lockoutSeconds--;
        });
      } else {
        timer.cancel();
        // 重新检查锁定状态
        try {
          final stillLocked = await _appLockService.isLockedOut;
          if (mounted) {
            setState(() {
              _isLockedOut = stillLocked;
            });
          }
        } catch (e) {
          debugPrint('LockScreen: 检查锁定状态失败: $e');
        }
      }
    });
  }

  void _onDigitPressed(String digit) {
    if (_passcode.length >= _passcodeLength || _isLockedOut) return;

    setState(() {
      _passcode += digit;
      _hasError = false;
      _errorMessage = '';
    });

    if (_passcode.length == _passcodeLength) {
      _verifyPasscode();
    }
  }

  void _onDeletePressed() {
    if (_passcode.isEmpty) return;

    setState(() {
      _passcode = _passcode.substring(0, _passcode.length - 1);
      _hasError = false;
      _errorMessage = '';
    });
  }

  Future<void> _verifyPasscode() async {
    try {
      final isValid = await _appLockService.verifyPasscode(_passcode);
      if (!mounted) return;

      if (isValid) {
        _appLockService.clearBackgroundTime();
        widget.onUnlocked();
      } else {
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}
        _dotsKey.currentState?.shake();

        // 检查是否被锁定
        await _checkLockout();

        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = _isLockedOut
                ? '尝试次数过多，请稍后重试'
                : '密码错误';
            _passcode = '';
          });
        }
      }
    } catch (e) {
      debugPrint('LockScreen: 验证密码失败: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isLockedOut || !mounted) return;

    try {
      final success = await _appLockService.authenticateWithBiometrics();
      if (success && mounted) {
        _appLockService.clearBackgroundTime();
        widget.onUnlocked();
      }
    } catch (e) {
      debugPrint('LockScreen: 生物识别失败: $e');
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6F1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE57373),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              '忘记密码？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4E3C),
              ),
            ),
          ],
        ),
        content: const Text(
          '为了保障您的隐私安全，瞬记不存储您的密码，因此无法找回。\n\n'
          '若必须重置，您需要卸载并重新安装 App。\n\n'
          '⚠️ 警告：此操作将删除所有未备份的本地日记。',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF5D4E3C),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(
                color: Color(0xFF8B7D6B),
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '我已知晓',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLockoutTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Logo
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFF5EBE0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 40,
                color: Color(0xFFC4A57B),
              ),
            ),
            const SizedBox(height: 24),

            // 标题
            const Text(
              '瞬记',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4E3C),
              ),
            ),
            const SizedBox(height: 8),

            // 副标题
            Text(
              _isLockedOut
                  ? '请在 ${_formatLockoutTime(_lockoutSeconds)} 后重试'
                  : '请输入密码解锁',
              style: TextStyle(
                fontSize: 15,
                color: _isLockedOut
                    ? const Color(0xFFE57373)
                    : const Color(0xFF8B7D6B),
              ),
            ),
            const SizedBox(height: 40),

            // 密码圆点
            ShakeablePasscodeDots(
              key: _dotsKey,
              length: _passcodeLength,
              filledCount: _passcode.length,
              hasError: _hasError,
            ),

            // 错误提示
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              child: _errorMessage.isNotEmpty
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE57373),
                        ),
                      ),
                    )
                  : null,
            ),

            const Spacer(flex: 1),

            // 数字键盘
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: PasscodeNumpad(
                onDigitPressed: _onDigitPressed,
                onDeletePressed: _onDeletePressed,
                onBiometricPressed: _showBiometricButton
                    ? _authenticateWithBiometrics
                    : null,
                biometricIcon: _biometricIcon,
              ),
            ),

            const SizedBox(height: 24),

            // 忘记密码
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text(
                '忘记密码？',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B7D6B),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
