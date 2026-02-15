/// AI服务授权对话框
/// 用于首次使用AI功能时请求用户授权
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AIAuthDialog extends StatelessWidget {
  const AIAuthDialog({super.key});

  /// 显示授权对话框（带模糊背景）
  static Future<bool?> show({required BuildContext context}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 必须明确选择
      barrierColor: Colors.black.withOpacity(0.5), // 半透明黑色背景
      builder: (context) => const AIAuthDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), // 模糊效果
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '欢迎使用Shunji',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2C),
                          height: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'WELCOME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B8B8B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 欢迎语
                  const Text(
                    '尊敬的用户，您好：欢迎使用Shunji！',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 规定说明标题
                  const Text(
                    '根据相关规定',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 规定说明正文
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B6B),
                        height: 1.7,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Shunji APP作为人工智能类应用，向您提供账号登录/注册、内容浏览/搜索/推荐及IM对话等基础服务。\n\n',
                        ),
                        const TextSpan(
                          text: '我们会通过《',
                        ),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => _openPrivacyPolicy(context),
                            child: const Text(
                              '用户协议',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFC4A57B),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A57B),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '》《'),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => _openPrivacyPolicy(context),
                            child: const Text(
                              '隐私协议',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFC4A57B),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A57B),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(
                          text:
                              '》中说明收集、处理您个人信息的情况：使用基础服务仅需要必要信息，您可拒绝其他信息授权，但可能无法使用部分功能。',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 详情链接
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B6B),
                        height: 1.7,
                      ),
                      children: [
                        const TextSpan(text: '详情请查看《'),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => _openPrivacyPolicy(context),
                            child: const Text(
                              '用户协议',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFC4A57B),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A57B),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '》《'),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => _openPrivacyPolicy(context),
                            child: const Text(
                              '隐私协议',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFC4A57B),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A57B),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '》内容。'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // "同意并继续"按钮
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '同意并继续',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "不同意"按钮
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        '不同意',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8B8B8B),
                        ),
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
