import 'package:flutter/material.dart';

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
}
