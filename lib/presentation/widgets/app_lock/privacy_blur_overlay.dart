/// 隐私保护遮罩
/// 在 App 进入后台时显示，防止多任务界面窥屏
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PrivacyBlurOverlay extends StatelessWidget {
  const PrivacyBlurOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bgPrimary,
                AppColors.accentLight,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo 容器
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 24),

                // 文字
                const Text(
                  '瞬记',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '安全保护中',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
