import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'about_screen.dart';
import 'export_screen.dart';
import '../app_lock/app_lock_settings_screen.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../../bloc/locale/locale_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.settings,
          style: const TextStyle(
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
          _buildSectionHeader(l10n.securityAndPrivacy),
          const SizedBox(height: 8),
          _buildNavItem(
            title: l10n.appLock,
            subtitle: l10n.appLockSubtitle,
            icon: Icons.lock_outline,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AppLockSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSwitchItem(
            title: l10n.aiServiceAuth,
            subtitle: l10n.aiServiceAuthSubtitle,
            icon: Icons.psychology_outlined,
            value: _aiAuthEnabled,
            onChanged: (value) => _handleAIAuthToggle(value),
          ),
          const SizedBox(height: 16),

          // 数据管理分组
          _buildSectionHeader(l10n.dataManagement),
          const SizedBox(height: 8),
          _buildNavItem(
            title: l10n.export,
            subtitle: l10n.exportSubtitle,
            icon: Icons.upload_file,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // 其他分组
          _buildSectionHeader(l10n.other),
          const SizedBox(height: 8),
          _buildLanguageItem(context, l10n),
          const SizedBox(height: 12),
          _buildNavItem(
            title: l10n.about,
            subtitle: l10n.aboutSubtitle,
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

  /// 语言设置项
  Widget _buildLanguageItem(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, state) {
        String currentLanguage;
        if (state.isFollowingSystem) {
          currentLanguage = l10n.languageSystem;
        } else if (state.effectiveLocale.languageCode == 'en') {
          currentLanguage = l10n.languageEnglish;
        } else {
          currentLanguage = l10n.languageChinese;
        }

        return InkWell(
          onTap: () => _showLanguageSelector(context, l10n),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                  child: const Icon(Icons.language, color: Color(0xFF8B7D6B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.language,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentLanguage,
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
      },
    );
  }

  /// 显示语言选择器
  void _showLanguageSelector(BuildContext context, AppLocalizations l10n) {
    final localeBloc = context.read<LocaleBloc>();
    final currentState = localeBloc.state;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(l10n.selectLanguage),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                localeBloc.add(const LocaleChange(null));
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.languageSystem),
                  if (currentState.isFollowingSystem) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Color(0xFFC4A57B), size: 20),
                  ],
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                localeBloc.add(const LocaleChange(Locale('zh')));
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.languageChinese),
                  if (!currentState.isFollowingSystem &&
                      currentState.effectiveLocale.languageCode == 'zh') ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Color(0xFFC4A57B), size: 20),
                  ],
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                localeBloc.add(const LocaleChange(Locale('en')));
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.languageEnglish),
                  if (!currentState.isFollowingSystem &&
                      currentState.effectiveLocale.languageCode == 'en') ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Color(0xFFC4A57B), size: 20),
                  ],
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        );
      },
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
              color: Colors.black.withValues(alpha: 0.04),
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
            color: Colors.black.withValues(alpha: 0.04),
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
            activeTrackColor: const Color(0xFFC4A57B),
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
    final l10n = AppLocalizations.of(context)!;
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.disableAIService),
        content: Text(l10n.disableAIServiceConfirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
