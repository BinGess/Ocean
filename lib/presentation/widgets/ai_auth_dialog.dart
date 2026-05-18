/// AI服务授权对话框
/// 用于首次使用AI功能时请求用户授权
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_typography.dart';

class AIAuthDialog extends StatelessWidget {
  const AIAuthDialog({super.key});

  /// 显示授权对话框（带模糊背景，底部弹出）
  static Future<bool?> show({required BuildContext context}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => const AIAuthDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行：文字 + 盾牌图标
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          '隐私功能使用协议',
                          style: AppTypography.modalTitle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 26,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 正文内容块（米色背景）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F0E8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: AppTypography.modalBody,
                        children: [
                          TextSpan(
                            text: '为提供 AI 情绪分析与结构化洞察服务，本应用集成了',
                          ),
                          TextSpan(
                            text: '火山引擎（字节跳动旗下云服务）',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text:
                                '提供的豆包大模型。\n\n只有在您确认后，我们才会将当前日记的文本内容加密传输至上述服务商。我们承诺不会包含您的手机号、姓名或设备标识符等个人身份信息，且数据仅用于实时分析，不用于模型训练。',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 隐私政策链接
                  Center(
                    child: GestureDetector(
                      onTap: () => _openPrivacyPolicy(context),
                      child: const Text(
                        '查看完整隐私政策 →',
                        style: AppTypography.modalCaption,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 同意按钮
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '同意并继续',
                        textAlign: TextAlign.center,
                        style: AppTypography.modalButtonPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 暂不开启
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Center(
                      child: Text(
                        '暂不开启',
                        style: AppTypography.modalBody.copyWith(
                          color: const Color(0xFF8F7760),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 提示文字
                  const Center(
                    child: Text(
                      '您可以随时在「设置」中重新开启',
                      style: AppTypography.modalCaption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    const url =
        'https://lucky-geranium-802.notion.site/Shunji-2fe407f7a70180c79746dbc59ad9a19d?pvs=74';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开隐私政策链接')),
      );
    }
  }
}
