import 'package:flutter/material.dart';
import 'app_colors.dart';

export 'app_colors.dart';

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
  static const double xxxxl = 40.0;

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
    color: AppColors.textTertiary,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle homeGreeting = TextStyle(
    fontSize: 32,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w600,
    height: 1.12,
    letterSpacing: -0.2,
    fontFamily: serifFamily,
    fontFamilyFallback: _serifFallback,
  );

  static const TextStyle quoteBody = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.55,
    letterSpacing: 0,
    color: AppColors.textSecondary,
    fontFamily: serifFamily,
    fontFamilyFallback: _serifFallback,
  );

  static const TextStyle quoteAuthor = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 0.8,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle recordHint = TextStyle(
    fontSize: 14,
    color: AppColors.textTertiary,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle recordTimer = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle transcriptionStatus = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle transcriptionBody = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
    height: 1.6,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle pageMeta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.1,
    color: AppColors.textSubtle,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle sectionSubtle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSubtle,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle bodyPrimary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.62,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.58,
    color: AppColors.textTertiary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle bodyQuote = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle timeLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textSubtle,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle chipLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: 0.1,
    color: AppColors.textTertiary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle actionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalBody = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.62,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  static const TextStyle modalCaption = TextStyle(
    fontSize: 13,
    color: AppColors.textSubtle,
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
    color: AppColors.textSecondary,
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
    color: AppColors.textPrimary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 详情页正文（比 bodyPrimary 稍大，适合阅读）
  static const TextStyle detailBody = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.58,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// AppBar 标题
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );

  /// 标签文字（用于情绪标签等）
  static const TextStyle tagLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.textSecondary,
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
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: _sansFallback,
  );
}
