import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/pro_subscription_service.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../l10n/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final ProSubscriptionService _proService;
  int _logoTapCount = 0;
  Timer? _tapResetTimer;
  late bool _showDebugSection;
  late bool _debugModeEnabled;
  bool _showOnboardingAlways = false;

  @override
  void initState() {
    super.initState();
    _proService = getIt<ProSubscriptionService>();
    _showDebugSection = _proService.debugMenuUnlocked;
    _debugModeEnabled = _proService.isDebugModeEnabled;
    _loadOnboardingAlwaysSetting();
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _onLogoTap() {
    if (_showDebugSection) return;

    _tapResetTimer?.cancel();
    _logoTapCount++;
    if (_logoTapCount >= 3) {
      _logoTapCount = 0;
      unawaited(_proService.setDebugMenuUnlocked(true));
      setState(() => _showDebugSection = true);
      return;
    }
    _tapResetTimer = Timer(const Duration(milliseconds: 1200), () {
      _logoTapCount = 0;
    });
  }

  void _onDebugModeChanged(bool value) {
    setState(() => _debugModeEnabled = value);
    unawaited(_proService.setDebugModeEnabled(value));
  }

  Future<void> _loadOnboardingAlwaysSetting() async {
    try {
      final db = getIt<HiveDatabase>();
      final value = db.settingsBox.get(
        'show_onboarding_always',
        defaultValue: false,
      );
      if (!mounted) return;
      setState(() => _showOnboardingAlways = value == true);
    } catch (_) {}
  }

  void _onShowOnboardingAlwaysChanged(bool value) {
    setState(() => _showOnboardingAlways = value);
    unawaited(
      getIt<HiveDatabase>().settingsBox.put('show_onboarding_always', value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '关于',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildAboutCard(context, l10n),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          GestureDetector(
            onTap: _onLogoTap,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 64,
              height: 64,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '情绪觉察日记 · 基于非暴力沟通（NVC）',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8B8B8B),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '版本号 ${AppConstants.appVersion}',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFB0B0B0),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _infoRow(
            label: '隐私协议',
            value: '查看',
            onTap: () {
              _openPrivacyPolicy(context);
            },
          ),
          _infoRow(
            label: '联系邮箱',
            value: 'baibin1989@foxmail.com',
          ),
          if (_showDebugSection) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDebugToggleRow(
              title: l10n.debugMode,
              subtitle: l10n.debugModeSubtitle,
              value: _debugModeEnabled,
              onChanged: _onDebugModeChanged,
            ),
            const SizedBox(height: 14),
            _buildDebugToggleRow(
              title: l10n.showOnboardingAlways,
              subtitle: l10n.showOnboardingAlwaysSubtitle,
              value: _showOnboardingAlways,
              onChanged: _onShowOnboardingAlwaysChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: onTap == null
                    ? const Color(0xFF8B8B8B)
                    : const Color(0xFF5A9FD4),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFFB0B0B0)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebugToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  color: Color(0xFF8B8B8B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CupertinoSwitch(
          value: value,
          activeTrackColor: AppColors.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    const url =
        'https://lucky-geranium-802.notion.site/Shunji-2fe407f7a70180c79746dbc59ad9a19d?pvs=74';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开隐私协议链接')),
      );
    }
  }
}
