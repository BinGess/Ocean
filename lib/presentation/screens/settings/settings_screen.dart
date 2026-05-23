import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'account_info_screen.dart';
import 'about_screen.dart';
import 'export_screen.dart';
import '../app_lock/app_lock_settings_screen.dart';
import '../pro/pro_purchase_screen.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../../bloc/locale/locale_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/services/pro_subscription_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiAuthEnabled = false;
  bool _signedIn = false;
  bool _logoutLoading = false;
  bool _deleteAccountLoading = false;
  late final AIAuthService _aiAuthService;
  OceanAccountService? _accountService;
  StreamSubscription? _authSubscription;
  StreamSubscription<void>? _accountDataSubscription;

  @override
  void initState() {
    super.initState();
    _aiAuthService = getIt<AIAuthService>();
    _accountService = getIt.isRegistered<OceanAccountService>()
        ? getIt<OceanAccountService>()
        : null;
    _loadAIAuthStatus();
    _loadAccountStatus();

    // 监听授权状态变化
    _authSubscription = _aiAuthService.authStateStream.listen((enabled) {
      if (mounted) {
        setState(() => _aiAuthEnabled = enabled);
      }
    });
    if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
      _accountDataSubscription =
          getIt<OceanAccountDataRefreshService>().changes.listen((_) {
        _loadAccountStatus();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _accountDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAIAuthStatus() async {
    final isAuthorized = await _aiAuthService.isAuthorized;
    if (mounted) {
      setState(() => _aiAuthEnabled = isAuthorized);
    }
  }

  Future<void> _loadAccountStatus() async {
    final service = _accountService;
    final signedIn = service != null && await service.isSignedIn;
    if (!mounted) return;
    setState(() => _signedIn = signedIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.settings,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 账号分组
          _buildSectionHeader('账号'),
          const SizedBox(height: 8),
          _buildNavItem(
            title: '账号信息',
            subtitle: _signedIn ? '查看手机号、昵称、头像和签名' : '当前未登录',
            icon: Icons.account_circle_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

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
            trailing: _buildProBadge(),
            onTap: () {
              if (getIt<ProSubscriptionService>().hasProFeatureAccess) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportScreen()),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProPurchaseScreen()),
                );
              }
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
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          if (_signedIn) ...[
            const SizedBox(height: 24),
            _buildLogoutButton(),
            const SizedBox(height: 12),
            _buildDeleteAccountButton(l10n),
          ],
          const SizedBox(height: 28),
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
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.language,
                      color: AppColors.textSecondary),
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentLanguage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
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
                    const Icon(Icons.check, color: AppColors.accent, size: 20),
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
                    const Icon(Icons.check, color: AppColors.accent, size: 20),
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
                    const Icon(Icons.check, color: AppColors.accent, size: 20),
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
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProBadge() {
    if (getIt<ProSubscriptionService>().hasProFeatureAccess) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4B896), AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Pro',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
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
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.textSecondary),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            const Icon(Icons.chevron_right, color: AppColors.primary),
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
    bool enabled = true,
    bool proRequired = false,
  }) {
    final needsPro =
        proRequired && !getIt<ProSubscriptionService>().hasProFeatureAccess;

    return GestureDetector(
      onTap: needsPro
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProPurchaseScreen()),
              );
            }
          : null,
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
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.textSecondary),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (needsPro) _buildProBadge(),
            if (needsPro)
              const Icon(Icons.chevron_right, color: AppColors.primary)
            else
              CupertinoSwitch(
                value: value,
                activeTrackColor: AppColors.accent,
                onChanged: enabled ? onChanged : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: _logoutLoading ? null : _confirmAndLogout,
      icon: _logoutLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout_rounded, size: 20),
      label: Text(_logoutLoading ? '正在退出...' : '退出登录'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: const Color(0xFFB95045),
        side: const BorderSide(color: Color(0xFFE9C9C4)),
        backgroundColor: const Color(0xFFFFFBFA),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
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

  Future<void> _confirmAndLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认退出登录？'),
        content: const Text('退出后会清除本机账号缓存；重新登录后，可从服务端恢复该账号的数据。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final service = _accountService;
    if (service == null) return;

    setState(() => _logoutLoading = true);
    try {
      await service.logout();
      if (!mounted) return;
      await _loadAccountStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已退出登录')),
      );
    } finally {
      if (mounted) {
        setState(() => _logoutLoading = false);
      }
    }
  }

  Widget _buildDeleteAccountButton(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: _deleteAccountLoading ? null : () => _confirmAndDeleteAccount(l10n),
      icon: _deleteAccountLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_forever_rounded, size: 20),
      label: Text(_deleteAccountLoading ? '正在删除...' : l10n.deleteAccount),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: const Color(0xFF8B1A10),
        side: const BorderSide(color: Color(0xFFE9B8B4)),
        backgroundColor: const Color(0xFFFFF8F7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteAccount(AppLocalizations l10n) async {
    // First confirmation
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAccountButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final service = _accountService;
    if (service == null) return;

    setState(() => _deleteAccountLoading = true);
    try {
      await service.deleteAccount();
      if (!mounted) return;
      await _loadAccountStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _deleteAccountLoading = false);
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
