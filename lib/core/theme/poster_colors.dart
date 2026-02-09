/// 分享海报色彩配置
/// 基于设计规范的动态色彩系统
library;

import 'package:flutter/material.dart';

/// 情绪能量类型
enum EmotionEnergy {
  /// 高能/紧张（焦虑、愤怒、兴奋）
  high,
  /// 低能/消极（悲伤、疲惫、失望）
  low,
  /// 中性/平静（平静、接纳、放松）
  neutral,
}

/// 海报色彩方案
class PosterColorScheme {
  /// 主背景色（渐变起始）
  final Color backgroundStart;
  /// 副背景色（渐变结束）
  final Color backgroundEnd;
  /// 主文字颜色
  final Color textPrimary;
  /// 次要文字颜色
  final Color textSecondary;
  /// 强调色
  final Color accent;
  /// 卡片背景色
  final Color cardBackground;
  /// 卡片边框色
  final Color cardBorder;

  const PosterColorScheme({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.cardBackground,
    required this.cardBorder,
  });
}

/// 海报颜色工具类
class PosterColors {
  /// 高能/紧张色彩方案（暖色调）
  static const PosterColorScheme highEnergy = PosterColorScheme(
    backgroundStart: Color(0xFFF5E6E0), // Muted peach
    backgroundEnd: Color(0xFFEDE0D4), // Warm beige
    textPrimary: Color(0xFF5C3A31), // Terracotta dark
    textSecondary: Color(0xFF8B6F66), // Warm grey
    accent: Color(0xFFB28C7F), // Terracotta
    cardBackground: Color(0xFFFFFBF8),
    cardBorder: Color(0xFFE8D5CC),
  );

  /// 低能/消极色彩方案（冷色调）
  static const PosterColorScheme lowEnergy = PosterColorScheme(
    backgroundStart: Color(0xFFE4EBF0), // Slate blue light
    backgroundEnd: Color(0xFFE8F0E5), // Sage green light
    textPrimary: Color(0xFF3D4F5F), // Slate blue dark
    textSecondary: Color(0xFF6B7F8C), // Cool grey
    accent: Color(0xFF8D9D86), // Sage
    cardBackground: Color(0xFFF8FBFA),
    cardBorder: Color(0xFFD1DDD8),
  );

  /// 中性/平静色彩方案（米色调）
  static const PosterColorScheme neutral = PosterColorScheme(
    backgroundStart: Color(0xFFFAF8F5), // Cream
    backgroundEnd: Color(0xFFF5F0E8), // Sand
    textPrimary: Color(0xFF4A4A4A), // Warm black
    textSecondary: Color(0xFF8B8B8B), // Warm grey
    accent: Color(0xFFC4A57B), // Gold/beige
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE8E4DC),
  );

  /// 情绪词到能量类型的映射
  static final Map<String, EmotionEnergy> emotionMapping = {
    // 高能/紧张
    '焦虑': EmotionEnergy.high,
    '愤怒': EmotionEnergy.high,
    '兴奋': EmotionEnergy.high,
    '紧张': EmotionEnergy.high,
    '烦躁': EmotionEnergy.high,
    '不安': EmotionEnergy.high,
    '急躁': EmotionEnergy.high,
    '恐惧': EmotionEnergy.high,
    '担忧': EmotionEnergy.high,
    '激动': EmotionEnergy.high,

    // 低能/消极
    '悲伤': EmotionEnergy.low,
    '疲惫': EmotionEnergy.low,
    '失望': EmotionEnergy.low,
    '沮丧': EmotionEnergy.low,
    '无力': EmotionEnergy.low,
    '孤独': EmotionEnergy.low,
    '忧郁': EmotionEnergy.low,
    '无奈': EmotionEnergy.low,
    '迷茫': EmotionEnergy.low,
    '委屈': EmotionEnergy.low,

    // 中性/平静
    '平静': EmotionEnergy.neutral,
    '接纳': EmotionEnergy.neutral,
    '放松': EmotionEnergy.neutral,
    '开心': EmotionEnergy.neutral,
    '感激': EmotionEnergy.neutral,
    '满足': EmotionEnergy.neutral,
    '好奇': EmotionEnergy.neutral,
    '思考': EmotionEnergy.neutral,
    '专注': EmotionEnergy.neutral,
    '期待': EmotionEnergy.neutral,
    '愧疚': EmotionEnergy.low,
    '不适': EmotionEnergy.high,
  };

  /// 根据情绪列表获取色彩方案
  static PosterColorScheme getSchemeForEmotions(List<String>? emotions) {
    if (emotions == null || emotions.isEmpty) {
      return neutral;
    }

    // 统计各能量类型的数量
    int highCount = 0;
    int lowCount = 0;
    int neutralCount = 0;

    for (final emotion in emotions) {
      final energy = emotionMapping[emotion] ?? EmotionEnergy.neutral;
      switch (energy) {
        case EmotionEnergy.high:
          highCount++;
          break;
        case EmotionEnergy.low:
          lowCount++;
          break;
        case EmotionEnergy.neutral:
          neutralCount++;
          break;
      }
    }

    // 返回数量最多的能量类型对应的色彩方案
    if (highCount >= lowCount && highCount >= neutralCount) {
      return highEnergy;
    } else if (lowCount >= highCount && lowCount >= neutralCount) {
      return lowEnergy;
    } else {
      return neutral;
    }
  }

  /// 获取情绪的能量类型
  static EmotionEnergy getEmotionEnergy(String emotion) {
    return emotionMapping[emotion] ?? EmotionEnergy.neutral;
  }

  /// 暗黑模式色彩方案
  static PosterColorScheme getDarkScheme(PosterColorScheme lightScheme) {
    if (lightScheme == highEnergy) {
      return const PosterColorScheme(
        backgroundStart: Color(0xFF2D1F1A),
        backgroundEnd: Color(0xFF1F1A17),
        textPrimary: Color(0xFFF5E6E0),
        textSecondary: Color(0xFFB8A39A),
        accent: Color(0xFFD4A99A),
        cardBackground: Color(0xFF3D2D26),
        cardBorder: Color(0xFF5C4A42),
      );
    } else if (lightScheme == lowEnergy) {
      return const PosterColorScheme(
        backgroundStart: Color(0xFF1A2228),
        backgroundEnd: Color(0xFF1A231F),
        textPrimary: Color(0xFFE4EBF0),
        textSecondary: Color(0xFF9BADB8),
        accent: Color(0xFFADBDA6),
        cardBackground: Color(0xFF263038),
        cardBorder: Color(0xFF3D4F5A),
      );
    } else {
      return const PosterColorScheme(
        backgroundStart: Color(0xFF1F1E1C),
        backgroundEnd: Color(0xFF2A2720),
        textPrimary: Color(0xFFFAF8F5),
        textSecondary: Color(0xFFB8B4AC),
        accent: Color(0xFFD4C4A0),
        cardBackground: Color(0xFF2F2D28),
        cardBorder: Color(0xFF4A4640),
      );
    }
  }
}
