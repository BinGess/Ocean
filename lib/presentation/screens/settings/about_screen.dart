import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/ocean_api_client.dart';
import '../../../core/services/pro_subscription_service.dart';
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
  // 彩蛋：UID（null = 加载中，'' = 未登录）
  String? _userId;

  @override
  void initState() {
    super.initState();
    _proService = getIt<ProSubscriptionService>();
    _showDebugSection = _proService.debugMenuUnlocked;
    _debugModeEnabled = _proService.isDebugModeEnabled;
    if (_showDebugSection) _loadUserId();
  }

  Future<void> _loadUserId() async {
    final id = await getIt<OceanApiClient>().currentUserId;
    if (mounted) setState(() => _userId = id ?? '');
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
      _loadUserId();
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
        color: AppColors.bgCard,
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
            style: AppTypography.modalTitle,
          ),
          const SizedBox(height: 6),
          Text(
            '情绪觉察日记 · 基于非暴力沟通（NVC）',
            style: AppTypography.sectionSubtle.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '版本号 ${AppConstants.appVersion}',
            style: AppTypography.chipLabel.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
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
            const SizedBox(height: 4),
            _buildUidRow(),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.debugMode,
                        style: AppTypography.sectionTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.debugModeSubtitle,
                        style: AppTypography.chipLabel.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoSwitch(
                  value: _debugModeEnabled,
                  activeTrackColor: AppColors.accent,
                  onChanged: _onDebugModeChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUidRow() {
    final uid = _userId;
    final isEmpty = uid == null || uid.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            'UID',
            style: AppTypography.pageMeta.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (uid == null)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Text(
              isEmpty ? '未登录' : uid,
              style: AppTypography.pageMeta.copyWith(
                color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                fontFamily: isEmpty ? null : 'Courier',
                fontSize: 13,
              ),
            ),
          if (!isEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('UID 已复制'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
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
              style: AppTypography.pageMeta.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: AppTypography.pageMeta.copyWith(
                color: onTap == null ? AppColors.textMuted : AppColors.primary,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.border),
            ],
          ],
        ),
      ),
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
