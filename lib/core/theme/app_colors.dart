library;

import 'package:flutter/material.dart';

/// 统一语义色板
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFC4A57B);
  static const Color primaryDark = Color(0xFF9D7D56);
  static const Color primarySoft = Color(0xFFF5EBE0);
  static const Color sage = Color(0xFF8D9D86);
  static const Color terracotta = Color(0xFFB28C7F);

  // Surface
  static const Color background = Color(0xFFFAF6F1);
  static const Color backgroundAlt = Color(0xFFF7F2EB);
  static const Color surface = Colors.white;
  static const Color surfaceSecondary = Color(0xFFF7F0E8);
  static const Color surfaceTertiary = Color(0xFFFFFCF8);
  static const Color inputBackground = Color(0xFFF2ECE4);
  static const List<Color> homeBackgroundGradient = <Color>[
    Color(0xFFEFF6FF),
    Color(0xFFF4F8FB),
    Color(0xFFFFF7ED),
  ];
  static const List<Color> warmPageBackgroundGradient = <Color>[
    Color(0xFFFFFCF8),
    Color(0xFFFDFBF6),
    Color(0xFFFCF8F1),
  ];
  static const Color pageWarmVeil = Color(0xFFF6EBDD);

  // Text
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF5D4E3C);
  static const Color textTertiary = Color(0xFF8B7D6B);
  static const Color textSubtle = Color(0xFFB8ADA0);
  static const Color textMuted = Color(0xFFA8A19A);

  // Border / Divider
  static const Color border = Color(0xFFE0D5C5);
  static const Color borderLight = Color(0xFFE9E1D7);
  static const Color divider = Color(0xFFE8E0D5);

  // Accent helpers
  static const Color accentBlue = Color(0xFF6B9FC2);
  static const Color accentBlueLight = Color(0xFFE7F2FA);

  // States
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF4A90E2);

  // Compatibility aliases
  static const Color accent = primary;
  static const Color accentLight = primarySoft;
  static const Color bgPrimary = background;
  static const Color bgCard = surface;
  static const Color bgCardSecondary = surfaceSecondary;
  static const Color bgInput = inputBackground;
  static const Color textMain = textPrimary;
  static const Color textLight = textSubtle;
  static const Color backgroundLight = background;
  static const Color surfaceLight = surface;

  // Mood colors
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
      bg: Color(0xFFF0E8DE),
      text: primaryDark,
      dot: primary,
    ),
    'Uncertainty': MoodColors(
      bg: Color(0xFFF3F1EE),
      text: Color(0xFF6A635B),
      dot: textSubtle,
    ),
  };
}

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
