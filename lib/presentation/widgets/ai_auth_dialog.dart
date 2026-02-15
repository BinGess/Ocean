/// AI服务授权对话框
/// 用于首次使用AI功能时请求用户授权
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AIAuthDialog extends StatelessWidget {
  const AIAuthDialog({super.key});

  /// 显示授权对话框
  static Future<bool?> show({required BuildContext context}) {
    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false, // 必须明确选择
      builder: (context) => const AIAuthDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: const Color(0xFFC4A57B),
          ),
          const SizedBox(height: 12),
          const Text(
            'AI服务授权',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('服务商', '火山引擎豆包大模型'),
            _buildInfoRow('数据范围', '仅日记文字内容'),
            _buildInfoRow('数据用途', '情绪分析及日记辅助'),
            _buildInfoRow('隐私保证', '不含个人身份信息，加密传输'),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => _openPrivacyPolicy(context),
                child: const Text(
                  '查看隐私政策',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFC4A57B),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '您可随时在设置中修改授权',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B7D6B),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('拒绝'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label：',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5D4E3C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8B7D6B),
              ),
            ),
          ),
        ],
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
