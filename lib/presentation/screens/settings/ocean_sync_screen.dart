import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/ocean_api_client.dart';
import '../../../core/services/ocean_account_input_validator.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/services/ocean_sync_service.dart';
import '../../../core/theme/app_colors.dart';

class OceanSyncScreen extends StatefulWidget {
  const OceanSyncScreen({super.key});

  @override
  State<OceanSyncScreen> createState() => _OceanSyncScreenState();
}

class _OceanSyncScreenState extends State<OceanSyncScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  late final OceanAccountService _accountService;
  late final OceanSyncService _syncService;
  late final OceanAccountDataRefreshService _refreshService;

  bool _loading = false;
  bool _signedIn = false;
  String? _email;
  String? _status;

  @override
  void initState() {
    super.initState();
    _accountService = getIt<OceanAccountService>();
    _syncService = getIt<OceanSyncService>();
    _refreshService = getIt<OceanAccountDataRefreshService>();
    _loadAccount();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final signedIn = await _accountService.isSignedIn;
    final email = await _accountService.currentEmail;
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _email = email;
      if (email != null) _emailController.text = email;
    });
  }

  Future<void> _run(String loadingText, Future<String> Function() task) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _status = loadingText;
    });
    try {
      final message = await task();
      await _loadAccount();
      if (!mounted) return;
      setState(() => _status = message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '操作失败：${_formatError(error)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final validation = _validateCredentials();
    if (validation != null) {
      setState(() => _status = validation);
      return;
    }
    await _run('正在注册、迁移本地数据并恢复服务端数据...', () async {
      await _accountService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim(),
      );
      return '注册成功，本地数据已迁移到服务端。';
    });
  }

  Future<void> _login() async {
    final validation = _validateCredentials();
    if (validation != null) {
      setState(() => _status = validation);
      return;
    }
    await _run('正在登录、迁移本地数据并恢复服务端数据...', () async {
      await _accountService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      return '登录成功，本地数据已迁移到服务端。';
    });
  }

  Future<void> _pushAllLocalData() async {
    await _run('正在上传本地数据...', () async {
      final result = await _syncService.pushAllLocalData();
      return '上传完成：接受 ${result.accepted} 项，忽略 ${result.ignored} 项。';
    });
  }

  Future<void> _restoreSnapshot() async {
    await _run('正在从服务端恢复数据...', () async {
      final result = await _syncService.restoreSnapshot();
      _refreshService.notifyChanged();
      return '恢复完成：写入 ${result.totalChanged} 项，其中记录 ${result.recordsChanged} 条，日总结 ${result.dailySummariesChanged} 条，报告 ${result.insightReportsChanged} 份。';
    });
  }

  Future<void> _pullChanges() async {
    await _run('正在拉取增量变更...', () async {
      final result = await _syncService.pullChanges();
      _refreshService.notifyChanged();
      return '拉取完成：更新 ${result.totalChanged} 项，其中记录 ${result.recordsChanged} 条，日总结 ${result.dailySummariesChanged} 条，报告 ${result.insightReportsChanged} 份。';
    });
  }

  Future<void> _logout() async {
    await _run('正在退出登录...', () async {
      await _accountService.logout();
      return '已退出登录。';
    });
  }

  String? _validateCredentials() {
    return OceanAccountInputValidator.validateEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  String _formatError(Object error) {
    if (error is OceanApiException) return error.displayMessage;
    if (error is OceanAuthException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
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
          '账号同步',
          style: TextStyle(
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
          _buildAccountCard(),
          const SizedBox(height: 16),
          if (_signedIn) _buildSyncCard(),
          if (_status != null) ...[
            const SizedBox(height: 16),
            _buildStatusCard(_status!),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _signedIn ? '已登录：${_email ?? 'Ocean 账号'}' : '登录 Ocean 账号',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _Input(
            controller: _emailController,
            label: '邮箱',
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
          ),
          const SizedBox(height: 12),
          _Input(
            controller: _passwordController,
            label: '密码（至少 8 位）',
            obscureText: true,
            enabled: !_loading,
          ),
          if (!_signedIn) ...[
            const SizedBox(height: 12),
            _Input(
              controller: _nicknameController,
              label: '昵称（注册时可选）',
              enabled: !_loading,
            ),
          ],
          const SizedBox(height: 16),
          if (_signedIn)
            _PrimaryButton(
              label: '退出登录',
              icon: Icons.logout,
              loading: _loading,
              onPressed: _logout,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _PrimaryButton(
                    label: '登录',
                    icon: Icons.login,
                    loading: _loading,
                    onPressed: _login,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SecondaryButton(
                    label: '注册',
                    loading: _loading,
                    onPressed: _register,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据同步',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(
            label: '上传本地数据',
            icon: Icons.cloud_upload_outlined,
            loading: _loading,
            onPressed: _pushAllLocalData,
          ),
          const SizedBox(height: 10),
          _SecondaryButton(
            label: '从服务端恢复完整快照',
            loading: _loading,
            onPressed: _restoreSnapshot,
          ),
          const SizedBox(height: 10),
          _SecondaryButton(
            label: '拉取增量变更',
            loading: _loading,
            onPressed: _pullChanges,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const CupertinoActivityIndicator()
          else
            const Icon(Icons.info_outline, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8F6F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: Color(0xFFE8E2D8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
