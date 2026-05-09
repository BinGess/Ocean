import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/ocean_api_client.dart';
import '../../../core/services/ocean_account_input_validator.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/theme/app_colors.dart';

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  late final OceanAccountService _accountService;

  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _accountService = getIt<OceanAccountService>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final validation = _validateCredentials();
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    await _run('正在登录并恢复数据...', () async {
      await _accountService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      widget.onComplete();
    });
  }

  Future<void> _register() async {
    final validation = _validateCredentials();
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    await _run('正在注册并迁移数据...', () async {
      await _accountService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim(),
      );
      widget.onComplete();
    });
  }

  Future<void> _run(String message, Future<void> Function() task) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = message;
    });
    try {
      await task();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '操作失败：${_formatError(error)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ocean 账号',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '登录后会优先从服务端恢复记录；也可以先跳过，继续把数据保存在本地。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                    const SizedBox(height: 12),
                    _Input(
                      controller: _nicknameController,
                      label: '昵称（注册时可选）',
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 20),
                    _PrimaryButton(
                      label: '登录',
                      loading: _loading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 10),
                    _SecondaryButton(
                      label: '注册并进入',
                      loading: _loading,
                      onPressed: _register,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading ? null : widget.onSkip,
                      child: const Text('先跳过，使用本地模式'),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      _MessageCard(message: _message!, loading: _loading),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.86),
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
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const CupertinoActivityIndicator(color: Colors.white)
          : Text(label),
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
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.loading});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (loading)
            const CupertinoActivityIndicator()
          else
            const Icon(Icons.info_outline, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
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
