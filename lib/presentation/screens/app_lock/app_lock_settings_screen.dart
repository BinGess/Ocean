/// 应用锁设置页面
/// 用于管理应用锁的各项设置
library;

import 'package:flutter/material.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/di/injection.dart';
import 'passcode_setup_screen.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _appLockService = getIt<AppLockService>();

  bool _isEnabled = false;
  bool _isBiometricEnabled = false;
  bool _canUseBiometrics = false;
  String _biometricName = '生物识别';
  AutoLockDuration _autoLockDuration = AutoLockDuration.immediately;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await _appLockService.isEnabled;
    final isBiometricEnabled = await _appLockService.isBiometricEnabled;
    final canUseBiometrics = await _appLockService.canUseBiometrics;
    final biometricName = await _appLockService.biometricName;
    final autoLockDuration = await _appLockService.autoLockDuration;

    if (mounted) {
      setState(() {
        _isEnabled = isEnabled;
        _isBiometricEnabled = isBiometricEnabled;
        _canUseBiometrics = canUseBiometrics;
        _biometricName = biometricName;
        _autoLockDuration = autoLockDuration;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      // 开启应用锁 - 设置密码
      final success = await PasscodeSetupScreen.show(
        context: context,
        mode: PasscodeSetupMode.setup,
      );
      if (success) {
        await _loadSettings();
      }
    } else {
      // 关闭应用锁 - 需要验证密码
      final passcode = await _showVerifyPasscodeDialog();
      if (passcode != null) {
        final success = await _appLockService.disable(passcode);
        if (success) {
          await _loadSettings();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('密码错误')),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // 启用生物识别前先验证
      final success = await _appLockService.authenticateWithBiometrics();
      if (success) {
        await _appLockService.setBiometricEnabled(true);
        await _loadSettings();
      }
    } else {
      await _appLockService.setBiometricEnabled(false);
      await _loadSettings();
    }
  }

  Future<void> _changePasscode() async {
    final success = await PasscodeSetupScreen.show(
      context: context,
      mode: PasscodeSetupMode.change,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已更改')),
      );
    }
  }

  Future<void> _selectAutoLockDuration() async {
    final selected = await showModalBottomSheet<AutoLockDuration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AutoLockDurationPicker(
        currentDuration: _autoLockDuration,
      ),
    );

    if (selected != null) {
      await _appLockService.setAutoLockDuration(selected);
      await _loadSettings();
    }
  }

  Future<String?> _showVerifyPasscodeDialog() async {
    String passcode = '';
    bool hasError = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFFFAF6F1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '验证密码',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4E3C),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '请输入密码以关闭应用锁',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B7D6B),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入密码',
                  counterText: '',
                  errorText: hasError ? '密码错误' : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8DED0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC4A57B)),
                  ),
                ),
                onChanged: (value) {
                  passcode = value;
                  if (hasError) {
                    setState(() => hasError = false);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                '取消',
                style: TextStyle(
                  color: Color(0xFF8B7D6B),
                  fontSize: 15,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (passcode.length >= 4) {
                  Navigator.of(context).pop(passcode);
                }
              },
              child: const Text(
                '确认',
                style: TextStyle(
                  color: Color(0xFFC4A57B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF5D4E3C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '应用锁',
          style: TextStyle(
            color: Color(0xFF5D4E3C),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 说明文字
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5EBE0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4A57B).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFC4A57B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '开启应用锁后，每次打开瞬记都需要验证身份，保护您的隐私安全。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5D4E3C),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 主开关
          _buildSettingCard(
            children: [
              _buildSwitchTile(
                icon: Icons.lock_outline,
                title: '启用应用锁',
                subtitle: '使用密码保护应用',
                value: _isEnabled,
                onChanged: _toggleAppLock,
              ),
            ],
          ),

          // 已启用时显示更多设置
          if (_isEnabled) ...[
            const SizedBox(height: 16),
            _buildSettingCard(
              children: [
                // 更改密码
                _buildTapTile(
                  icon: Icons.password,
                  title: '更改密码',
                  onTap: _changePasscode,
                ),
                const Divider(height: 1, indent: 56),

                // 生物识别
                if (_canUseBiometrics)
                  _buildSwitchTile(
                    icon: _biometricName.contains('Face')
                        ? Icons.face
                        : Icons.fingerprint,
                    title: '使用 $_biometricName',
                    subtitle: '快速解锁',
                    value: _isBiometricEnabled,
                    onChanged: _toggleBiometric,
                  ),
                if (_canUseBiometrics)
                  const Divider(height: 1, indent: 56),

                // 自动锁定时间
                _buildTapTile(
                  icon: Icons.timer_outlined,
                  title: '自动锁定',
                  trailing: Text(
                    _autoLockDuration.label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8B7D6B),
                    ),
                  ),
                  onTap: _selectAutoLockDuration,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EBE0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFC4A57B),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5D4E3C),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8B7D6B),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFC4A57B),
          ),
        ],
      ),
    );
  }

  Widget _buildTapTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EBE0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFC4A57B),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ),
            if (trailing != null) trailing,
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFB8ADA0),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// 自动锁定时间选择器
class _AutoLockDurationPicker extends StatelessWidget {
  final AutoLockDuration currentDuration;

  const _AutoLockDurationPicker({
    required this.currentDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD4C4B0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              '自动锁定时间',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4E3C),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 选项列表
          ...AutoLockDuration.values.map((duration) {
            final isSelected = duration == currentDuration;
            return InkWell(
              onTap: () => Navigator.of(context).pop(duration),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        duration.label,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? const Color(0xFFC4A57B)
                              : const Color(0xFF5D4E3C),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check,
                        color: Color(0xFFC4A57B),
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),

          // 底部安全区
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
