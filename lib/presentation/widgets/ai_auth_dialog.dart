/// AI服务授权对话框
/// 用于首次使用AI功能时请求用户授权
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AIAuthDialog extends StatelessWidget {
  const AIAuthDialog({super.key});

  /// 显示授权对话框（带模糊背景，底部弹出）
  static Future<bool?> show({required BuildContext context}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
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
                color: Colors.black.withOpacity(0.12),
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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C2C2C),
                            height: 1.3,
                          ),
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
                          color: Color(0xFFC4A57B),
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
                    child: const Text(
                      'AI 分析功能由火山引擎豆包大模型提供支持。处理过程仅传输您的日记文字内容，用于情绪分析与日记辅助生成，数据不含任何身份信息，且全程加密传输。',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B6059),
                        height: 1.7,
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
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFC4A57B),
                          fontWeight: FontWeight.w500,
                        ),
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
                        color: const Color(0xFFC4A57B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '同意并继续',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 暂不开启
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: const Center(
                      child: Text(
                        '暂不开启',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 提示文字
                  const Center(
                    child: Text(
                      '您可以随时在「设置」中重新开启',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBBBBBB),
                      ),
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
