/// 应用色彩配置 — 唯一色彩来源
/// 合并了主题色、品牌色、文字色阶、情绪色彩等所有色彩定义
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── 主色调 ──────────────────────────────────────────────
  /// Material 主题种子色（用于 ColorScheme.fromSeed）
  static const Color primary = Color(0xFF48697A);
  static const Color primaryDark = Color(0xFF365160);

  // ── 品牌/强调色 ────────────────────────────────────────
  static const Color accent = Color(0xFFC4A57B);
  static const Color accentLight = Color(0xFFF5EBE0);
  static const Color accentWarm = Color(0xFFFFF8E7);

  // ── 次要颜色（情绪相关） ───────────────────────────────
  static const Color sage = Color(0xFF8D9D86);
  static const Color terracotta = Color(0xFFB28C7F);

  // ── 文字色阶 ──────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF5D4E3C);
  static const Color textTertiary = Color(0xFF8B7D6B);
  static const Color textSubtle = Color(0xFFB8ADA0);
  static const Color textMuted = Color(0xFFAAAAAA);

  // ── 背景色阶 ──────────────────────────────────────────
  static const Color bgPrimary = Color(0xFFFAF6F1);
  static const Color bgCard = Color(0xFFFFFCF8);
  static const Color bgCardSecondary = Color(0xFFF7F0E8);
  static const Color bgInput = Color(0xFFF5F5F5);
  static const List<Color> homeBackgroundGradient = <Color>[
    Color(0xFFF4F8FC),
    Color(0xFFF7F6F2),
    Color(0xFFFFF7ED),
  ];
  static const List<Color> warmPageBackgroundGradient = <Color>[
    Color(0xFFFFFCF8),
    Color(0xFFFDFBF6),
    Color(0xFFFCF8F1),
  ];
  static const Color pageWarmVeil = Color(0xFFF6EBDD);

  /// @deprecated 使用 bgPrimary 代替
  static const Color background = bgPrimary;

  // ── 边框/分割线 ───────────────────────────────────────
  static const Color border = Color(0xFFE0D5C5);
  static const Color borderLight = Color(0xFFE8DED0);
  static const Color divider = Color(0xFFE8E0D5);

  // ── 功能色 ────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF2196F3);

  // ── 情绪颜色（对应 MOOD_COLORS） ─────────────────────
  static const Map<String, MoodColors> moodColors = {
    'HighPleasure': MoodColors(
      bg: Color(0xFFE8F0E5),
      text: Color(0xFF4A5746),
      dot: sage,
    ),
    'LowAnxiety': MoodColors(
      bg: Color(0xFFF3E8E5),
      text: Color(0xFF5C3A31),
      dot: terracotta,
    ),
    'Calm': MoodColors(
      bg: Color(0xFFF5F5F4),
      text: Color(0xFF57534E),
      dot: Color(0xFFA8A29E),
    ),
    'Focus': MoodColors(
      bg: Color(0xFFE6EEF2),
      text: primary,
      dot: primary,
    ),
    'Uncertainty': MoodColors(
      bg: Color(0xFFF3F4F6),
      text: Color(0xFF4B5563),
      dot: Color(0xFF9CA3AF),
    ),
  };
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
