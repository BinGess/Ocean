import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'about_screen.dart';
import 'export_screen.dart';
import '../app_lock/app_lock_settings_screen.dart';
import '../pro/pro_purchase_screen.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../../bloc/locale/locale_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/services/icloud_sync_service.dart';
import '../../../core/services/pro_subscription_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiAuthEnabled = false;
  bool _iCloudSyncEnabled = false;
  bool _iCloudAvailable = false;
  bool _iCloudStatusLoading = false;
  ICloudBackupStatus? _iCloudBackupStatus;
  bool _showOnboardingAlways = false;
  late final AIAuthService _aiAuthService;
  late final ICloudSyncService _iCloudSyncService;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _aiAuthService = getIt<AIAuthService>();
    _iCloudSyncService = getIt<ICloudSyncService>();
    _loadAIAuthStatus();
    _loadICloudStatus();
    _loadOnboardingAlwaysSetting();

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

  Future<void> _loadICloudStatus() async {
    if (mounted) {
      setState(() => _iCloudStatusLoading = true);
    }

    final enabled = await _iCloudSyncService.isEnabled;
    final available = await _iCloudSyncService.isAvailable;
    final backupStatus = await _iCloudSyncService.getBackupStatus();
    if (mounted) {
      setState(() {
        _iCloudSyncEnabled = enabled;
        _iCloudAvailable = available;
        _iCloudBackupStatus = backupStatus;
        _iCloudStatusLoading = false;
      });
    }
  }

  Future<void> _loadOnboardingAlwaysSetting() async {
    try {
      final db = getIt<HiveDatabase>();
      final value =
          db.settingsBox.get('show_onboarding_always', defaultValue: false);
      if (mounted) {
        setState(() => _showOnboardingAlways = value == true);
      }
    } catch (_) {}
  }

  Future<void> _handleOnboardingAlwaysToggle(bool value) async {
    try {
      final db = getIt<HiveDatabase>();
      await db.settingsBox.put('show_onboarding_always', value);
      setState(() => _showOnboardingAlways = value);
    } catch (_) {}
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
          const SizedBox(height: 12),
          _buildSwitchItem(
            title: l10n.iCloudSync,
            subtitle: _iCloudAvailable
                ? l10n.iCloudSyncSubtitle
                : l10n.iCloudSyncUnavailable,
            icon: Icons.cloud_outlined,
            value: _iCloudSyncEnabled,
            onChanged: (value) => _handleICloudSyncToggle(value),
            proRequired: true,
          ),
          if (_iCloudAvailable) ...[
            const SizedBox(height: 8),
            _buildICloudStatusCard(l10n),
          ],
          const SizedBox(height: 16),

          // 其他分组
          _buildSectionHeader(l10n.other),
          const SizedBox(height: 8),
          _buildSwitchItem(
            title: l10n.showOnboardingAlways,
            subtitle: l10n.showOnboardingAlwaysSubtitle,
            icon: Icons.waving_hand_outlined,
            value: _showOnboardingAlways,
            onChanged: _handleOnboardingAlwaysToggle,
          ),
          const SizedBox(height: 12),
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
                color: const Color(0xFFF8F6F3),
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
                color: const Color(0xFFF8F6F3),
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
                onChanged: onChanged,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildICloudStatusCard(AppLocalizations l10n) {
    final status = _iCloudBackupStatus;
    final subtitle = _iCloudStatusLoading
        ? l10n.iCloudBackupChecking
        : _formatICloudBackupStatus(l10n, status);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8DF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status?.backupExists == true
                ? Icons.cloud_done_outlined
                : Icons.cloud_queue_outlined,
            size: 20,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.iCloudBackupStatusTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatICloudBackupStatus(
    AppLocalizations l10n,
    ICloudBackupStatus? status,
  ) {
    if (status == null) return l10n.iCloudBackupChecking;
    if (!status.backupExists) return l10n.iCloudBackupNotFound;

    final syncedAt = status.exportedAt == null
        ? l10n.iCloudBackupTimeUnknown
        : _formatDateTime(status.exportedAt!);
    final size = _formatFileSize(status.fileSizeBytes);

    return '${l10n.iCloudBackupLastSynced}: $syncedAt\n'
        '${l10n.iCloudBackupContent}: ${status.recordCount} ${l10n.iCloudBackupRecords}, '
        '${status.weeklyInsightCount} ${l10n.iCloudBackupWeeklyInsights}, '
        '${status.insightReportCount} ${l10n.iCloudBackupReports}\n'
        '${l10n.iCloudBackupFile}: ${status.fileName} · $size';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/$month/$day $hour:$minute';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
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

  Future<void> _handleICloudSyncToggle(bool value) async {
    final l10n = AppLocalizations.of(context)!;

    if (value && !_iCloudAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.iCloudSyncUnavailable)),
      );
      return;
    }

    try {
      await _iCloudSyncService.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _iCloudSyncEnabled = value;
      });
      await _loadICloudStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? l10n.iCloudSyncEnabled : l10n.iCloudSyncDisabled,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _iCloudSyncEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.iCloudSyncFailed)),
      );
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
