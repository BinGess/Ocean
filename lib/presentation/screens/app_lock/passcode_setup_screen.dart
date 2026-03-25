/// 密码设置页面
/// 用于首次设置密码或更改密码
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/di/injection.dart';
import '../../widgets/app_lock/passcode_numpad.dart';
import '../../widgets/app_lock/passcode_dots.dart';

/// 设置模式
enum PasscodeSetupMode {
  /// 首次设置密码
  setup,
  /// 更改密码
  change,
}

class PasscodeSetupScreen extends StatefulWidget {
  final PasscodeSetupMode mode;

  const PasscodeSetupScreen({
    super.key,
    this.mode = PasscodeSetupMode.setup,
  });

  /// 显示密码设置页面
  static Future<bool> show({
    required BuildContext context,
    PasscodeSetupMode mode = PasscodeSetupMode.setup,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasscodeSetupScreen(mode: mode),
        fullscreenDialog: true,
      ),
    );
    return result ?? false;
  }

  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

enum _SetupStep {
  /// 更改密码时：验证旧密码
  verifyOld,
  /// 输入新密码
  enterNew,
  /// 确认新密码
  confirmNew,
  /// 询问是否启用生物识别
  askBiometric,
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  final _appLockService = getIt<AppLockService>();
  final _dotsKey = GlobalKey<ShakeablePasscodeDotsState>();

  late _SetupStep _currentStep;
  String _passcode = '';
  String _newPasscode = '';
  bool _hasError = false;
  String _errorMessage = '';

  // 密码长度（4位或6位）
  final int _passcodeLength = 4;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.mode == PasscodeSetupMode.change
        ? _SetupStep.verifyOld
        : _SetupStep.enterNew;
  }

  String get _title {
    switch (_currentStep) {
      case _SetupStep.verifyOld:
        return '验证当前密码';
      case _SetupStep.enterNew:
        return widget.mode == PasscodeSetupMode.change ? '输入新密码' : '设置密码';
      case _SetupStep.confirmNew:
        return '确认密码';
      case _SetupStep.askBiometric:
        return '启用生物识别';
    }
  }

  String get _subtitle {
    switch (_currentStep) {
      case _SetupStep.verifyOld:
        return '请输入当前密码以继续';
      case _SetupStep.enterNew:
        return '请输入 $_passcodeLength 位数字密码';
      case _SetupStep.confirmNew:
        return '请再次输入密码以确认';
      case _SetupStep.askBiometric:
        return '';
    }
  }

  void _onDigitPressed(String digit) {
    if (_passcode.length >= _passcodeLength) return;

    setState(() {
      _passcode += digit;
      _hasError = false;
      _errorMessage = '';
    });

    if (_passcode.length == _passcodeLength) {
      _onPasscodeComplete();
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

  Future<void> _onPasscodeComplete() async {
    switch (_currentStep) {
      case _SetupStep.verifyOld:
        // 验证旧密码
        final isValid = await _appLockService.verifyPasscode(_passcode);
        if (isValid) {
          setState(() {
            _passcode = '';
            _currentStep = _SetupStep.enterNew;
          });
        } else {
          _showError('密码错误，请重试');
        }
        break;

      case _SetupStep.enterNew:
        // 保存新密码，进入确认步骤
        setState(() {
          _newPasscode = _passcode;
          _passcode = '';
          _currentStep = _SetupStep.confirmNew;
        });
        break;

      case _SetupStep.confirmNew:
        // 确认密码
        if (_passcode == _newPasscode) {
          // 设置密码
          final success = await _appLockService.setPasscode(_newPasscode);
          if (success) {
            // 检查是否支持生物识别
            if (await _appLockService.canUseBiometrics) {
              setState(() {
                _currentStep = _SetupStep.askBiometric;
              });
            } else {
              // 不支持生物识别，直接完成
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            }
          } else {
            _showError('设置失败，请重试');
          }
        } else {
          _showError('密码不匹配，请重试');
          setState(() {
            _passcode = '';
            _newPasscode = '';
            _currentStep = _SetupStep.enterNew;
          });
        }
        break;

      case _SetupStep.askBiometric:
        // 这个步骤不需要输入密码
        break;
    }
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    _dotsKey.currentState?.shake();
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _passcode = '';
    });
  }

  Future<void> _enableBiometric() async {
    await _appLockService.setBiometricEnabled(true);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _skipBiometric() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF6F1),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF5D4E3C)),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: _currentStep == _SetupStep.askBiometric
            ? _buildBiometricPrompt()
            : _buildPasscodeInput(),
      ),
    );
  }

  Widget _buildPasscodeInput() {
    return Column(
      children: [
        const Spacer(flex: 1),

        // 标题
        Text(
          _title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5D4E3C),
          ),
        ),
        const SizedBox(height: 8),

        // 副标题
        Text(
          _subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF8B7D6B),
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
          ),
        ),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildBiometricPrompt() {
    return FutureBuilder<String>(
      future: _appLockService.biometricName,
      builder: (context, snapshot) {
        final biometricName = snapshot.data ?? '生物识别';
        final icon = biometricName.contains('Face')
            ? Icons.face
            : Icons.fingerprint;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 图标
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5EBE0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 32),

              // 标题
              Text(
                '启用 $biometricName？',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
              const SizedBox(height: 16),

              // 说明
              Text(
                '使用 $biometricName 可以更快速地解锁瞬记，\n同时保持高度安全性。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8B7D6B),
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // 启用按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _enableBiometric,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    '启用 $biometricName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 跳过按钮
              TextButton(
                onPressed: _skipBiometric,
                child: const Text(
                  '稍后设置',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8B7D6B),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
