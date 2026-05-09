import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../../../core/di/injection.dart';
import '../../../core/network/ocean_api_client.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../bloc/insight/insight_bloc.dart';
import '../../bloc/insight/insight_event.dart';
import '../../bloc/insight/insight_state.dart';
import '../../widgets/insights/weekly_analysis_section.dart';
import '../pro/pro_purchase_screen.dart';
import '../settings/settings_screen.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({
    super.key,
    this.proScreenBuilder,
    this.settingsScreenBuilder,
  });

  final WidgetBuilder? proScreenBuilder;
  final WidgetBuilder? settingsScreenBuilder;

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late final HiveDatabase _database;
  OceanUserDataApi? _userDataApi;
  String? _avatar;
  String? _nickname;
  String? _signature;
  StreamSubscription<void>? _accountDataSubscription;

  @override
  void initState() {
    super.initState();
    _database = getIt<HiveDatabase>();
    _userDataApi =
        getIt.isRegistered<OceanApiClient>() ? getIt<OceanApiClient>() : null;
    _loadProfile();
    if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
      _accountDataSubscription =
          getIt<OceanAccountDataRefreshService>().changes.listen((_) {
        if (!mounted) return;
        setState(_loadProfile);
      });
    }
    context.read<InsightBloc>().add(const InsightLoadCurrentWeek());
  }

  @override
  void dispose() {
    _accountDataSubscription?.cancel();
    super.dispose();
  }

  void _loadProfile() {
    _avatar = _database.settingsBox.get('profile_avatar') as String?;
    _nickname = _database.settingsBox.get('profile_nickname') as String?;
    _signature = _database.settingsBox.get('profile_signature') as String?;
  }

  Future<void> _onRefresh() async {
    context.read<InsightBloc>().add(const InsightLoadCurrentWeek());
  }

  Future<void> _saveProfile({
    required String avatar,
    required String nickname,
    required String signature,
  }) async {
    final normalizedAvatar = avatar.trim();
    final normalizedNickname = nickname.trim();
    final normalizedSignature = signature.trim();

    final clientUpdatedAt = DateTime.now().toUtc().toIso8601String();
    var avatarToCache = normalizedAvatar;
    var nicknameToCache = normalizedNickname;
    var signatureToCache = normalizedSignature;

    final api = _userDataApi;
    if (api != null && await api.isSignedIn) {
      final response = await api.updateProfile({
        'avatar': normalizedAvatar,
        'nickname': normalizedNickname,
        'signature': normalizedSignature,
        'clientUpdatedAt': clientUpdatedAt,
      });
      final data = response['data'];
      if (data is Map) {
        avatarToCache = data['avatar']?.toString() ?? '';
        nicknameToCache = data['nickname']?.toString() ?? '';
        signatureToCache = data['signature']?.toString() ?? '';
      }
    }

    await _database.settingsBox.put('profile_avatar', avatarToCache);
    await _database.settingsBox.put('profile_nickname', nicknameToCache);
    await _database.settingsBox.put('profile_signature', signatureToCache);
    await _database.settingsBox.put(
      'ocean_sync_updated_at_profile_me',
      clientUpdatedAt,
    );

    if (!mounted) return;
    setState(() {
      _avatar = avatarToCache;
      _nickname = nicknameToCache;
      _signature = signatureToCache;
    });
  }

  Future<void> _showEditProfileDialog(AppLocalizations l10n) async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return _EditProfileDialog(
          l10n: l10n,
          avatar: _profileAvatar(l10n),
          nickname: _profileNickname(l10n),
          signature: _profileSignature(l10n),
          onSave: _saveProfile,
        );
      },
    );
  }

  String _profileAvatar(AppLocalizations l10n) {
    final value = _avatar?.trim();
    return value == null || value.isEmpty ? l10n.profileAvatarDefault : value;
  }

  String _profileNickname(AppLocalizations l10n) {
    final value = _nickname?.trim();
    return value == null || value.isEmpty ? l10n.profileNickname : value;
  }

  String _profileSignature(AppLocalizations l10n) {
    final value = _signature?.trim();
    return value == null || value.isEmpty ? l10n.profileSubtitle : value;
  }

  void _openProScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: widget.proScreenBuilder ?? (_) => const ProPurchaseScreen(),
      ),
    );
  }

  void _openSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: widget.settingsScreenBuilder ?? (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.warmPageBackgroundGradient,
            stops: [0.0, 0.62, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.accent,
            backgroundColor: AppColors.bgCard,
            child: BlocBuilder<InsightBloc, InsightState>(
              builder: (context, state) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ProfileHeader(
                        avatar: _profileAvatar(l10n),
                        nickname: _profileNickname(l10n),
                        signature: _profileSignature(l10n),
                        l10n: l10n,
                        onEdit: () => _showEditProfileDialog(l10n),
                      ),
                    ),
                    if (state.weeklyAnalysis != null)
                      SliverToBoxAdapter(
                        child: WeeklyAnalysisSection(
                          analysis: state.weeklyAnalysis!,
                          compact: true,
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: _WeeklyAnalysisPlaceholder(
                          isLoading: state.status == InsightStatus.loading ||
                              state.status == InsightStatus.generating,
                          l10n: l10n,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: _SettingsEntrySection(
                        l10n: l10n,
                        onManageSubscription: _openProScreen,
                        onMoreSettings: _openSettingsScreen,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.l10n,
    required this.avatar,
    required this.nickname,
    required this.signature,
    required this.onSave,
  });

  final AppLocalizations l10n;
  final String avatar;
  final String nickname;
  final String signature;
  final Future<void> Function({
    required String avatar,
    required String nickname,
    required String signature,
  }) onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _avatarController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _signatureController;

  @override
  void initState() {
    super.initState();
    _avatarController = TextEditingController(text: widget.avatar);
    _nicknameController = TextEditingController(text: widget.nickname);
    _signatureController = TextEditingController(text: widget.signature);
  }

  @override
  void dispose() {
    _avatarController.dispose();
    _nicknameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave(
      avatar: _avatarController.text,
      nickname: _nicknameController.text,
      signature: _signatureController.text,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.textSecondary.withValues(alpha: 0.14),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.editProfile,
              style: AppTypography.modalTitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 3,
                ),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _avatarController,
                builder: (context, value, _) {
                  final avatar = value.text.trim().isEmpty
                      ? widget.l10n.profileAvatarDefault
                      : value.text.trim();
                  return Text(
                    avatar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.pageTitle.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _ProfileTextField(
              controller: _avatarController,
              label: l10n.profileAvatar,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _ProfileTextField(
              controller: _nicknameController,
              label: l10n.profileNicknameLabel,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _ProfileTextField(
              controller: _signatureController,
              label: l10n.profileSignature,
              textInputAction: TextInputAction.done,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.textInputAction,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: AppTypography.bodyPrimary.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.sectionSubtle.copyWith(
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.bgCardSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatar,
    required this.nickname,
    required this.signature,
    required this.l10n,
    required this.onEdit,
  });

  final String avatar;
  final String nickname;
  final String signature;
  final AppLocalizations l10n;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Semantics(
        button: true,
        label: l10n.editProfile,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentWarm,
                        AppColors.accentLight,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textSecondary.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    avatar,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.pageTitle.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.pageTitle.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        signature,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsEntrySection extends StatelessWidget {
  const _SettingsEntrySection({
    required this.l10n,
    required this.onManageSubscription,
    required this.onMoreSettings,
  });

  final AppLocalizations l10n;
  final VoidCallback onManageSubscription;
  final VoidCallback onMoreSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingsEntryTile(
            title: l10n.manageSubscription,
            icon: Icons.workspace_premium_outlined,
            iconColor: AppColors.accent,
            iconBgColor: AppColors.accentWarm,
            onTap: onManageSubscription,
          ),
          const Divider(
            height: 1,
            indent: 64,
            color: AppColors.borderLight,
          ),
          _SettingsEntryTile(
            title: l10n.moreSettings,
            icon: Icons.settings_outlined,
            iconColor: AppColors.primary,
            iconBgColor: const Color(0xFFEAF1F4),
            onTap: onMoreSettings,
          ),
        ],
      ),
    );
  }
}

class _SettingsEntryTile extends StatelessWidget {
  const _SettingsEntryTile({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyPrimary.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyAnalysisPlaceholder extends StatelessWidget {
  const _WeeklyAnalysisPlaceholder({
    required this.isLoading,
    required this.l10n,
  });

  final bool isLoading;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentWarm,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : const Icon(
                    Icons.insights_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLoading ? l10n.generatingInsight : l10n.myWeeklyUnavailable,
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
