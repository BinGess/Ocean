import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/pro_subscription_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class ProPurchaseScreen extends StatefulWidget {
  const ProPurchaseScreen({super.key});

  @override
  State<ProPurchaseScreen> createState() => _ProPurchaseScreenState();
}

class _ProPurchaseScreenState extends State<ProPurchaseScreen> {
  late final ProSubscriptionService _proService;
  StreamSubscription<bool>? _statusSubscription;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _proService = getIt<ProSubscriptionService>();

    // 监听订阅状态变化（购买/恢复成功后自动更新 UI）
    _statusSubscription = _proService.statusStream.listen((isPro) {
      if (!mounted) return;
      if (isPro) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.proSubscribeSuccess)),
        );
      }
      setState(() {
        _purchasing = false;
        _restoring = false;
      });
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = _proService.isPro;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.proMembership,
          style: const TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildProBadge(l10n),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildFeatureCard(
                    icon: Icons.upload_file,
                    title: l10n.proFeatureExport,
                    description: l10n.proFeatureExportDesc,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    icon: Icons.cloud_outlined,
                    title: l10n.proFeatureICloud,
                    description: l10n.proFeatureICloudDesc,
                    color: const Color(0xFF7190A5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isPro
                  ? _buildAlreadyProBanner(l10n)
                  : _buildSubscribeButton(l10n),
            ),
            const SizedBox(height: 16),
            if (!isPro)
              _restoring
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B8B8B)),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _handleRestore,
                      child: Text(
                        l10n.proRestorePurchase,
                        style: const TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 14,
                        ),
                      ),
                    ),
            // 订阅说明
            if (!isPro)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Text(
                  l10n.proSubscriptionNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFAAAAAA),
                    height: 1.6,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProBadge(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4B896), AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.proPurchaseTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            l10n.proPurchaseSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF8B8B8B),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8B8B8B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 订阅按钮 - 优先使用 App Store 返回的真实价格
  Widget _buildSubscribeButton(AppLocalizations l10n) {
    final buttonText = _proService.productDetails != null
        ? '${l10n.proSubscribeNow} — ${_proService.priceString}/${l10n.proPerMonth}'
        : l10n.proSubscribeButton;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _purchasing ? null : _handleSubscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _purchasing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildAlreadyProBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            l10n.proAlreadySubscribed,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _purchasing = true);

    final success = await _proService.purchase();
    if (!success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      final errorMsg = _proService.errorMessage ?? l10n.proSubscribeFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
      setState(() => _purchasing = false);
    }
    // 购买成功的 UI 更新由 statusStream 监听处理
  }

  Future<void> _handleRestore() async {
    setState(() => _restoring = true);

    await _proService.restorePurchases();

    // 等待一小段时间让 purchaseStream 处理恢复结果
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (_proService.isPro) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.proAlreadySubscribed)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.proRestoreNone)),
      );
    }
    setState(() => _restoring = false);
  }
}
