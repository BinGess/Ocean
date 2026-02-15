import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'about_screen.dart';
import 'export_screen.dart';
import '../app_lock/app_lock_settings_screen.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiAuthEnabled = false;
  late final AIAuthService _aiAuthService;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _aiAuthService = getIt<AIAuthService>();
    _loadAIAuthStatus();

    // 监听授权状态变化
    _authSubscription = _aiAuthService.authStateStream.listen((enabled) {
      if (mounted) {
        setState(() => _aiAuthEnabled = enabled);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAIAuthStatus() async {
    final isAuthorized = await _aiAuthService.isAuthorized;
    if (mounted) {
      setState(() => _aiAuthEnabled = isAuthorized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 安全与隐私分组
          _buildSectionHeader('安全与隐私'),
          const SizedBox(height: 8),
          _buildNavItem(
            title: '应用锁',
            subtitle: '使用密码或生物识别保护隐私',
            icon: Icons.lock_outline,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppLockSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSwitchItem(
            title: 'AI服务授权',
            subtitle: '允许使用火山引擎豆包大模型分析日记',
            icon: Icons.psychology_outlined,
            value: _aiAuthEnabled,
            onChanged: (value) => _handleAIAuthToggle(value),
          ),
          const SizedBox(height: 16),

          // 数据管理分组
          _buildSectionHeader('数据管理'),
          const SizedBox(height: 8),
          _buildNavItem(
            title: '导出',
            subtitle: '导出所有记录或洞察信息',
            icon: Icons.upload_file,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // 其他分组
          _buildSectionHeader('其他'),
          const SizedBox(height: 8),
          _buildNavItem(
            title: '关于',
            subtitle: '应用信息与隐私协议',
            icon: Icons.info_outline,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B7D6B),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF8B7D6B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF8B7D6B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B8B8B),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: const Color(0xFFC4A57B),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 处理AI授权开关切换
  Future<void> _handleAIAuthToggle(bool value) async {
    if (value) {
      // 开启授权：显示授权对话框
      final result = await AIAuthDialog.show(context: context);
      if (result == true) {
        await _aiAuthService.grant();
        // Stream会自动更新UI
      }
    } else {
      // 关闭授权：显示确认对话框
      final confirmed = await _showRevokeConfirmation();
      if (confirmed == true) {
        await _aiAuthService.revoke();
        // Stream会自动更新UI
      }
    }
  }

  /// 显示撤销授权确认对话框
  Future<bool?> _showRevokeConfirmation() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('关闭AI服务'),
        content: const Text('关闭后将无法使用NVC情绪分析和周洞察功能，是否继续？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
