/// 应用色彩配置
/// 对应 React 版本的 Tailwind 配置
library;

import 'package:flutter/material.dart';

class AppColors {
  // 主色调
  static const Color primary = Color(0xFF48697A);
  static const Color primaryDark = Color(0xFF365160);

  // 次要颜色
  static const Color sage = Color(0xFF8D9D86);
  static const Color terracotta = Color(0xFFB28C7F);

  // 背景颜色
  static const Color background = Color(0xFFFBFAF9);
  static const Color backgroundLight = Color(0xFFFBFAF9);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // 文字颜色
  static const Color textPrimary = Color(0xFF3F4652);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textMain = Color(0xFF3F4652);
  static const Color textLight = Color(0xFF9CA3AF);

  // 边框颜色
  static const Color border = Color(0xFFE5E7EB);

  // 情绪颜色（对应 MOOD_COLORS）
  static const Map<String, MoodColors> moodColors = {
    'HighPleasure': MoodColors(
      bg: Color(0xFFE8F0E5), // sage/20
      text: Color(0xFF4A5746),
      dot: sage,
    ),
    'LowAnxiety': MoodColors(
      bg: Color(0xFFF3E8E5), // terracotta/20
      text: Color(0xFF5C3A31),
      dot: terracotta,
    ),
    'Calm': MoodColors(
      bg: Color(0xFFF5F5F4), // stone-100
      text: Color(0xFF57534E), // stone-600
      dot: Color(0xFFA8A29E), // stone-400
    ),
    'Focus': MoodColors(
      bg: Color(0xFFE6EEF2), // primary/10
      text: primary,
      dot: primary,
    ),
    'Uncertainty': MoodColors(
      bg: Color(0xFFF3F4F6), // gray-100
      text: Color(0xFF4B5563), // gray-600
      dot: Color(0xFF9CA3AF), // gray-400
    ),
  };

  // 系统颜色
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

/// 情绪颜色配置
class MoodColors {
  final Color bg;
  final Color text;
  final Color dot;

  const MoodColors({
    required this.bg,
    required this.text,
    required this.dot,
  });
}
