/// 加载遮罩组件
/// 显示加载状态和进度信息

import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isLoading;

  const LoadingOverlay({
    super.key,
    this.message,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示加载对话框
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingOverlay(message: message),
    );
  }

  /// 隐藏加载对话框
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}
