import 'package:flutter/material.dart';

/// 全局间距规范 - 基于 4px 网格系统
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  /// 页面水平内边距（统一 20px）
  static const double pageHorizontal = 20.0;
  /// 页面顶部内边距
  static const double pageTop = 16.0;
  /// 卡片内边距
  static const double cardPadding = 16.0;
  /// 卡片圆角
  static const double cardRadius = 12.0;
  /// 大卡片圆角
  static const double cardRadiusLg = 20.0;
}

/// 全局颜色规范
class AppColors {
  AppColors._();

  // 文字色阶
  static const Color textPrimary = Color(0xFF2C2C2C);      // 最深 - 页面标题
  static const Color textSecondary = Color(0xFF5D4E3C);     // 次深 - 正文/区块标题
  static const Color textTertiary = Color(0xFF8B7D6B);      // 中等 - 辅助说明
  static const Color textSubtle = Color(0xFFB8ADA0);        // 最浅 - 时间/元信息
  static const Color textMuted = Color(0xFFAAAAAA);         // 灰色 - 占位/禁用

  // 品牌/强调色
  static const Color accent = Color(0xFFC4A57B);            // 主强调色
  static const Color accentLight = Color(0xFFF5EBE0);       // 强调色浅底
  static const Color accentWarm = Color(0xFFFFF8E7);        // 暖黄底色

  // 背景色阶
  static const Color bgPrimary = Color(0xFFFAF6F1);         // 主背景（暖米色）
  static const Color bgCard = Colors.white;                  // 卡片背景
  static const Color bgCardSecondary = Color(0xFFF7F0E8);   // 次级卡片背景
  static const Color bgInput = Color(0xFFF5F5F5);           // 输入框背景

  // 边框/分割线
  static const Color border = Color(0xFFE0D5C5);            // 主边框
  static const Color borderLight = Color(0xFFE8DED0);       // 浅边框
  static const Color divider = Color(0xFFE8E0D5);           // 分割线

  // 功能色
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF2196F3);
}

class AppTypography {
  AppTypography._();

  static const String serifFamily = 'Noto Serif SC';
  static const String sansFamily = 'Noto Sans SC';

  static const List<String> _serifFallback = [
    'Songti SC',
    'STSong',
    'Source Han Serif SC',
    'Times New Roman',
  ];

  static const List<String> _sansFallback = [
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Roboto',
  ];

  static const TextStyle homeDate = TextStyle(
    fontSize: 13,
    color: Color(0xFF9A846C),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.7,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle homeGreeting = TextStyle(
    fontSize: 32,
    color: Color(0xFF5D4E3C),
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 0.35,
    fontFamily: serifFamily,
    fontFamilyFallback: _serifFallback,
  );

  static const TextStyle quoteBody = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.72,
    letterSpacing: 0.15,
    color: Color(0xFF5D4E3C),
    fontFamily: serifFamily,
    fontFamilyFallback: _serifFallback,
  );

  static const TextStyle quoteAuthor = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF937A61),
    letterSpacing: 1.4,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle recordHint = TextStyle(
    fontSize: 14,
    color: Color(0xFF8F7760),
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle recordTimer = TextStyle(
    fontSize: 16,
    color: Color(0xFF7A5B37),
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle transcriptionStatus = TextStyle(
    fontSize: 12,
    color: Color(0xFF8B7D6B),
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle transcriptionBody = TextStyle(
    fontSize: 16,
    color: Color(0xFF7A5B37),
    height: 1.6,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.35,
    color: Color(0xFF2C2C2C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle pageMeta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.1,
    color: Color(0xFFB8ADA0),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
    color: Color(0xFF5D4E3C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle sectionSubtle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: Color(0xFFA79A8A),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle bodyPrimary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.65,
    color: Color(0xFF5D4E3C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: Color(0xFF6F6256),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle bodyQuote = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: Color(0xFF5D4E3C),
    fontStyle: FontStyle.italic,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle timeLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: Color(0xFFA89D92),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle chipLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: 0.1,
    color: Color(0xFF8B7D6B),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle actionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
    color: Color(0xFF5D4E3C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Color(0xFF2C2C2C),
    height: 1.25,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalBody = TextStyle(
    fontSize: 15,
    color: Color(0xFF6D6158),
    height: 1.6,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalCaption = TextStyle(
    fontSize: 13,
    color: Color(0xFFA18F7D),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalButtonPrimary = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalButtonSecondary = TextStyle(
    fontSize: 16,
    color: Color(0xFF6B6059),
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 详情页标题（卡片内标题，比 sectionTitle 稍大）
  static const TextStyle detailTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: Color(0xFF2C2C2C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 详情页正文（比 bodyPrimary 稍大，适合阅读）
  static const TextStyle detailBody = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: Color(0xFF4A4A4A),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// AppBar 标题
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF8B7D6B),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 标签文字（用于情绪标签等）
  static const TextStyle tagLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: Color(0xFF5D4E3C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 按钮文字（大按钮）
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 按钮文字（中等按钮）
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF5D4E3C),
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );
}
