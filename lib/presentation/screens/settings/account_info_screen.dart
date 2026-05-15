import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/services/ocean_record_ownership_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../l10n/app_localizations.dart';
import '../account/account_entry_screen.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late final HiveDatabase _database;
  OceanAccountService? _accountService;
  OceanRecordOwnershipService? _ownershipService;
  StreamSubscription<void>? _accountDataSubscription;

  bool _signedIn = false;
  bool _accountLoaded = false;
  String? _phone;
  String? _email;
  String? _avatar;
  String? _nickname;
  String? _signature;

  @override
  void initState() {
    super.initState();
    _database = getIt<HiveDatabase>();
    _accountService = getIt.isRegistered<OceanAccountService>()
        ? getIt<OceanAccountService>()
        : null;
    _ownershipService = getIt.isRegistered<OceanRecordOwnershipService>()
        ? getIt<OceanRecordOwnershipService>()
        : null;
    _loadAccountInfo();
    if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
      _accountDataSubscription =
          getIt<OceanAccountDataRefreshService>().changes.listen((_) {
        _loadAccountInfo();
      });
    }
  }

  @override
  void dispose() {
    _accountDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    final service = _accountService;
    final signedIn = service != null && await service.isSignedIn;
    final phone = signedIn ? await service.currentPhone : null;
    final email = signedIn ? await service.currentEmail : null;
    final profileVisible = _isEntityVisible('profile', 'me');
    final avatar = profileVisible
        ? _database.settingsBox.get('profile_avatar') as String?
        : null;
    final nickname = profileVisible
        ? _database.settingsBox.get('profile_nickname') as String?
        : null;
    final signature = profileVisible
        ? _database.settingsBox.get('profile_signature') as String?
        : null;

    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _accountLoaded = true;
      _phone = phone;
      _email = email;
      _avatar = avatar;
      _nickname = nickname;
      _signature = signature;
    });
  }

  bool _isEntityVisible(String entityType, String entityId) {
    final ownership = _ownershipService;
    if (ownership == null) return true;
    return ownership.isEntityVisible(
      entityType: entityType,
      entityId: entityId,
      accountKey: ownership.activeAccount,
    );
  }

  Future<void> _openAccountScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountEntryScreen(
          onComplete: () => Navigator.of(context).pop(),
          onSkip: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (!mounted) return;
    await _loadAccountInfo();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avatar = _displayValue(_avatar, l10n.profileAvatarDefault);
    final nickname = _displayValue(_nickname, l10n.profileNickname);
    final signature = _displayValue(_signature, l10n.profileSubtitle);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '账号信息',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar:
          _accountLoaded && !_signedIn ? _buildLoginBar() : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _buildProfileHeader(
            avatar: avatar,
            nickname: nickname,
            signature: signature,
          ),
          const SizedBox(height: 16),
          _buildInfoGroup(
            children: [
              _buildInfoRow(
                icon: Icons.phone_iphone_rounded,
                label: '手机号',
                value: _displayValue(_phone, _signedIn ? '未绑定' : '未登录'),
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.badge_outlined,
                label: '昵称',
                value: nickname,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.face_retouching_natural_outlined,
                label: '头像',
                value: avatar,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.edit_note_rounded,
                label: '签名',
                value: signature,
              ),
              if (_email != null && _email!.trim().isNotEmpty) ...[
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: '邮箱',
                  value: _email!.trim(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '个人资料可在「我的」页面顶部编辑，登录后会保存到服务端。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton.icon(
        onPressed: _openAccountScreen,
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('登录'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppColors.textSecondary,
          foregroundColor: AppColors.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required String avatar,
    required String nickname,
    required String signature,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentWarm,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              avatar,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  signature,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
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

  Widget _buildInfoGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 66),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }

  String _displayValue(String? value, String fallback) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }
}
