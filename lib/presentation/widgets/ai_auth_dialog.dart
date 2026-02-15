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
                        'AI功能使用协议',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2C),
                          height: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.psychology_outlined,
                          size: 20,
                          color: Color(0xFFC4A57B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 分隔线
                  Container(
                    height: 1,
                    color: const Color(0xFFF0F0F0),
                  ),
                  const SizedBox(height: 20),

                  // 服务商
                  _buildInfoSection(
                    label: '服务商',
                    content: '本应用AI功能由第三方提供商「火山引擎豆包大模型」提供技术支持。',
                  ),
                  const SizedBox(height: 16),

                  // 数据范围
                  _buildInfoSection(
                    label: '数据范围',
                    content: '仅传输您输入的日记文字内容，不包含其他信息。',
                  ),
                  const SizedBox(height: 16),

                  // 数据用途
                  _buildInfoSection(
                    label: '数据用途',
                    content: '仅用于情绪分析及日记辅助生成，不作他用。',
                  ),
                  const SizedBox(height: 16),

                  // 隐私保证
                  _buildInfoSection(
                    label: '隐私保证',
                    content: '数据不包含任何个人身份信息（如手机号、姓名等），且全程加密传输。',
                  ),
                  const SizedBox(height: 20),

                  // 隐私政策链接
                  Center(
                    child: GestureDetector(
                      onTap: () => _openPrivacyPolicy(context),
                      child: const Text(
                        '查看完整隐私政策 →',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFC4A57B),
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFFC4A57B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // "同意"按钮
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

                  // "拒绝"按钮
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        '暂不开启',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8B8B8B),
                        ),
                      ),
                    ),
                  ),

                  // 提示文字
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      '您可以随时在「设置」中重新开启',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB8B8B8),
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

  /// 构建信息项
  Widget _buildInfoSection({
    required String label,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4E3C),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B6B6B),
              height: 1.5,
            ),
          ),
        ),
      ],
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
