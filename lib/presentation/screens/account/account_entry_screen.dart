import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/di/injection.dart';
import '../../../core/network/ocean_api_client.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/theme/app_colors.dart';

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
    this.protectLocalData = false,
  });

  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final bool protectLocalData;

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();

  late final OceanAccountService _accountService;

  bool _loading = false;
  bool _sendingSms = false;
  int _smsCooldown = 0;
  Timer? _smsTimer;
  bool _agreementsAccepted = false;
  bool _localMigrationRetryAvailable = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _accountService = getIt<OceanAccountService>();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    _smsTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendSmsCode() async {
    if (_localMigrationRetryAvailable) {
      setState(() => _message = '验证码已经通过，请直接重试上传本机数据。');
      return;
    }
    if (!_ensureAgreementsAccepted()) return;
    final validation = _validatePhone();
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    if (_sendingSms || _smsCooldown > 0) return;
    setState(() {
      _sendingSms = true;
      _message = '正在发送验证码...';
    });
    try {
      await _accountService.sendSmsCode(phone: _normalizedPhone());
      if (!mounted) return;
      setState(() {
        _message = '验证码已发送，5 分钟内有效';
        _smsCooldown = 60;
      });
      _smsTimer?.cancel();
      _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_smsCooldown <= 1) {
          timer.cancel();
          setState(() => _smsCooldown = 0);
          return;
        }
        setState(() => _smsCooldown -= 1);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '发送失败：${_formatError(error)}');
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  Future<void> _loginWithSms() async {
    if (_localMigrationRetryAvailable) {
      await _retryLocalMigration();
      return;
    }
    if (!_ensureAgreementsAccepted()) return;
    final phoneValidation = _validatePhone();
    if (phoneValidation != null) {
      setState(() => _message = phoneValidation);
      return;
    }
    final code = _smsCodeController.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      setState(() => _message = '请输入正确的验证码');
      return;
    }
    await _run('正在登录并恢复数据...', () async {
      await _accountService.loginWithSms(
        phone: _normalizedPhone(),
        code: code,
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
      setState(() {
        if (error is OceanLocalMigrationException) {
          _localMigrationRetryAvailable = true;
        }
        _message = '操作失败：${_formatError(error)}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryLocalMigration() async {
    await _run('正在重新上传本机数据...', () async {
      await _accountService.retryLocalMigration();
      if (!mounted) return;
      setState(() => _localMigrationRetryAvailable = false);
      widget.onComplete();
    });
  }

  String? _validatePhone() {
    if (!RegExp(r'^(\+?86)?1[3-9]\d{9}$').hasMatch(_normalizedPhone())) {
      return '请输入正确的手机号';
    }
    return null;
  }

  String _normalizedPhone() {
    return _phoneController.text.replaceAll(RegExp(r'[\s-]'), '').trim();
  }

  String _formatError(Object error) {
    if (error is OceanApiException) return error.displayMessage;
    if (error is OceanAuthException) return error.message;
    return error.toString();
  }

  bool _ensureAgreementsAccepted() {
    if (_agreementsAccepted) return true;
    setState(() => _message = '请先阅读并同意用户协议和隐私政策');
    return false;
  }

  void _openLegalDocument(_LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LegalDocumentScreen(document: document),
      ),
    );
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
          child: Align(
            alignment: const Alignment(0, -0.2),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.water_drop_outlined,
                                  color: AppColors.accent,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '登录后可以将记录同步到云端，安全可靠',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PhoneLoginForm(
                          phoneController: _phoneController,
                          codeController: _smsCodeController,
                          loading: _loading,
                          sendingSms: _sendingSms,
                          cooldown: _smsCooldown,
                          retryMigration: _localMigrationRetryAvailable,
                          onSendCode: _sendSmsCode,
                          onLogin: _loginWithSms,
                        ),
                        const SizedBox(height: 14),
                        _AgreementConsentRow(
                          accepted: _agreementsAccepted,
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(() {
                                    _agreementsAccepted = value ?? false;
                                    if (_agreementsAccepted &&
                                        _message == '请先阅读并同意用户协议和隐私政策') {
                                      _message = null;
                                    }
                                  });
                                },
                          onUserAgreementTap: () =>
                              _openLegalDocument(_LegalDocument.userAgreement),
                          onPrivacyPolicyTap: () =>
                              _openLegalDocument(_LegalDocument.privacyPolicy),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: _loading ? null : widget.onSkip,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            foregroundColor: AppColors.textSecondary,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('先跳过，使用本地模式'),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 14),
                          _MessageCard(message: _message!, loading: _loading),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LegalDocument {
  userAgreement,
  privacyPolicy,
}

class _AgreementConsentRow extends StatelessWidget {
  const _AgreementConsentRow({
    required this.accepted,
    required this.onChanged,
    required this.onUserAgreementTap,
    required this.onPrivacyPolicyTap,
  });

  final bool accepted;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback onUserAgreementTap;
  final VoidCallback onPrivacyPolicyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Checkbox(
            value: accepted,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '我已阅读并同意',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                _LegalLink(
                  label: '《用户协议》',
                  onTap: onUserAgreementTap,
                ),
                const Text(
                  '和',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                _LegalLink(
                  label: '《隐私政策》',
                  onTap: onPrivacyPolicyTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.document});

  final _LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final title = switch (document) {
      _LegalDocument.userAgreement => '用户协议',
      _LegalDocument.privacyPolicy => '隐私政策',
    };
    final sections = switch (document) {
      _LegalDocument.userAgreement => _userAgreementSections,
      _LegalDocument.privacyPolicy => _privacyPolicySections,
    };

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemBuilder: (context, index) {
          final section = sections[index];
          return _LegalSectionView(section: section);
        },
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemCount: sections.length,
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _userAgreementSections = [
  _LegalSection(
    '生效与适用',
    '本协议适用于您使用 Ocean（瞬记）提供的账号、记录、语音转写、AI 分析、数据同步等服务。您点击同意、注册、登录或继续使用相关服务，即表示您已阅读并同意本协议。',
  ),
  _LegalSection(
    '账号使用',
    '您可以使用手机号验证码登录。请妥善保管账号信息，不得将账号用于违法违规用途。因您主动泄露验证码或设备管理不当导致的损失，由您自行承担。',
  ),
  _LegalSection(
    '服务内容',
    'Ocean 用于个人记录、情绪觉察和自我回顾。AI 生成内容仅供参考，不构成医疗诊断、心理咨询、法律或其他专业建议。如您处于紧急或严重心理困扰状态，请及时联系专业机构或当地紧急救助服务。',
  ),
  _LegalSection(
    '用户内容',
    '您对自己主动输入、录音转写和上传同步的内容负责。请勿发布或保存违法违规、侵犯他人权益或泄露他人隐私的内容。您可以在 App 内删除记录，也可以联系我们处理账号数据删除或注销请求。',
  ),
  _LegalSection(
    '协议变更',
    '我们可能因法律法规或产品功能变化更新本协议。涉及您重大权益的变更，我们会在 App 内以显著方式提示。',
  ),
];

const _privacyPolicySections = [
  _LegalSection(
    '版本信息',
    '版本号：V1.5\n生效日期：2026年2月15日\n更新日期：2026年5月27日',
  ),
  _LegalSection(
    '我们收集的信息',
    '为提供账号登录、数据同步、记录、语音转写和 AI 洞察功能，我们可能处理您的手机号、邮箱、登录状态、昵称、头像文本、签名、文字记录、语音转写文本、情绪/感受/需要分析、每日心情、每日总结、周报/月报、设备型号、系统版本、App 版本、错误日志、IP 地址和 User-Agent。',
  ),
  _LegalSection(
    '使用目的',
    '我们使用上述信息用于账号识别与安全验证、保存和恢复记录、跨设备同步、生成情绪洞察和报告、排查故障、保障服务安全。我们遵循最小必要原则，不会将您的个人信息用于与本服务无关的广告追踪或用户画像。',
  ),
  _LegalSection(
    '权限说明',
    '麦克风权限仅在您使用语音记录或语音转文字功能时使用；网络权限用于登录、同步、短信验证码、语音识别和 AI 服务；本地存储用于保存本地记录、缓存和设置。您可以在系统设置中关闭相关权限。',
  ),
  _LegalSection(
    '第三方服务',
    '我们可能使用阿里云短信服务发送验证码，使用火山引擎/豆包等服务完成语音识别和 AI 分析，使用 Ocean 服务端及云基础设施保存账号与同步数据。我们不会出售您的个人信息，并会要求第三方仅在实现对应功能所必需的范围内处理数据。',
  ),
  _LegalSection(
    '存储与安全',
    '您的账号和同步数据原则上存储于中华人民共和国境内。我们会通过 HTTPS 加密传输、密码哈希、刷新令牌哈希、访问控制和日志脱敏等方式保护数据安全。服务端不以备份目的保存原始音频文件。',
  ),
  _LegalSection(
    '您的权利',
    '您可以访问、更正、删除 App 内的记录和个人资料；可以关闭 AI 功能、撤回麦克风权限、退出登录；也可以通过联系方式申请注销账号或删除服务端数据。我们通常会在完成身份核验后 15 个工作日内回复。',
  ),
  _LegalSection(
    '未成年人保护',
    '本应用主要面向成年人。未满 14 周岁的未成年人应在监护人同意和陪同下使用。监护人如发现未成年人未经同意提交个人信息，可以联系我们处理。',
  ),
  _LegalSection(
    '联系我们',
    '如您对隐私政策或个人信息处理有疑问，请通过电子邮件联系我们：baibin1989@foxmail.com。',
  ),
];

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.keyboardType,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  widthFactor: 1,
                  child: suffix,
                ),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
    );
  }
}

class _PhoneLoginForm extends StatelessWidget {
  const _PhoneLoginForm({
    required this.phoneController,
    required this.codeController,
    required this.loading,
    required this.sendingSms,
    required this.cooldown,
    required this.retryMigration,
    required this.onSendCode,
    required this.onLogin,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool loading;
  final bool sendingSms;
  final int cooldown;
  final bool retryMigration;
  final VoidCallback onSendCode;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Input(
          controller: phoneController,
          label: '手机号',
          keyboardType: TextInputType.phone,
          enabled: !loading && !retryMigration,
        ),
        const SizedBox(height: 12),
        if (retryMigration)
          _Input(
            controller: codeController,
            label: '验证码',
            keyboardType: TextInputType.number,
            enabled: false,
          )
        else
          _Input(
            controller: codeController,
            label: '验证码',
            keyboardType: TextInputType.number,
            enabled: !loading,
            suffix: _SmsCodeButton(
              loading: loading,
              sendingSms: sendingSms,
              cooldown: cooldown,
              onPressed: onSendCode,
            ),
          ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: retryMigration ? '重试上传本机数据' : '登录',
          loading: loading,
          onPressed: onLogin,
        ),
      ],
    );
  }
}

class _SmsCodeButton extends StatelessWidget {
  const _SmsCodeButton({
    required this.loading,
    required this.sendingSms,
    required this.cooldown,
    required this.onPressed,
  });

  final bool loading;
  final bool sendingSms;
  final int cooldown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || sendingSms || cooldown > 0;
    final label = cooldown > 0 ? '$cooldown秒' : '获取验证码';

    return Semantics(
      button: true,
      enabled: !disabled,
      label: cooldown > 0 ? '$label后可重新获取验证码' : label,
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.accent,
          disabledForegroundColor: AppColors.textMuted,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: sendingSms
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CupertinoActivityIndicator(radius: 8),
              )
            : Text(label),
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
        minimumSize: const Size.fromHeight(54),
        backgroundColor: AppColors.accent,
        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: loading
          ? const CupertinoActivityIndicator(color: Colors.white)
          : Text(label),
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
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
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
