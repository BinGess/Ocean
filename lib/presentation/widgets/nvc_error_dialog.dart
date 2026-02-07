import 'package:flutter/material.dart';

/// NVC分析错误对话框
/// 当AI分析失败时显示友好的错误提示
class NVCErrorDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSaveText;

  const NVCErrorDialog({
    super.key,
    required this.onRetry,
    required this.onSaveText,
  });

  static Future<NVCErrorAction?> show({
    required BuildContext context,
  }) {
    return showDialog<NVCErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NVCErrorDialog(
        onRetry: () => Navigator.of(context).pop(NVCErrorAction.retry),
        onSaveText: () => Navigator.of(context).pop(NVCErrorAction.saveText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 错误图标
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4E6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
            ),

            const SizedBox(height: 24),

            // 标题
            const Text(
              '智能体开小差了',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
              ),
            ),

            const SizedBox(height: 12),

            // 提示文字
            Text(
              '可以先保存文本\n稍后再进行NVC分析',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.6,
              ),
            ),

            const SizedBox(height: 32),

            // 按钮组
            Column(
              children: [
                // 立即重试按钮
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '立即重试',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 保存文本按钮
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onSaveText,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      '先保存文本',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// NVC错误对话框的操作枚举
enum NVCErrorAction {
  retry,    // 立即重试
  saveText, // 保存文本
}
