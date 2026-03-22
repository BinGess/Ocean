import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

/// 每日心情数据
class DailyMood {
  final String imagePath;
  final String label;
  final Color color;
  final String fallbackEmoji;

  const DailyMood({
    required this.imagePath,
    required this.label,
    required this.color,
    required this.fallbackEmoji,
  });
}

/// 预定义的心情选项
const List<DailyMood> dailyMoods = [
  DailyMood(
      imagePath: 'assets/images/moods/happy.png',
      label: '开心',
      color: Color(0xFFFFD93D),
      fallbackEmoji: '😊'),
  DailyMood(
      imagePath: 'assets/images/moods/calm.png',
      label: '平静',
      color: Color(0xFF6BCB77),
      fallbackEmoji: '😌'),
  DailyMood(
      imagePath: 'assets/images/moods/loved.png',
      label: '幸福',
      color: Color(0xFFFF6B6B),
      fallbackEmoji: '🥰'),
  DailyMood(
      imagePath: 'assets/images/moods/sad.png',
      label: '低落',
      color: Color(0xFF748DA6),
      fallbackEmoji: '😔'),
  DailyMood(
      imagePath: 'assets/images/moods/annoyed.png',
      label: '烦躁',
      color: Color(0xFFFF8B4D),
      fallbackEmoji: '😤'),
  DailyMood(
      imagePath: 'assets/images/moods/anxious.png',
      label: '焦虑',
      color: Color(0xFF9B7EDE),
      fallbackEmoji: '😰'),
  DailyMood(
      imagePath: 'assets/images/moods/tired.png',
      label: '疲惫',
      color: Color(0xFFB4B4B4),
      fallbackEmoji: '😴'),
  DailyMood(
      imagePath: 'assets/images/moods/confused.png',
      label: '困惑',
      color: Color(0xFF4ECDC4),
      fallbackEmoji: '🤔'),
];

/// 默认心情（开心）
const DailyMood defaultMood = DailyMood(
  imagePath: 'assets/images/moods/happy.png',
  label: '开心',
  color: Color(0xFFFFD93D),
  fallbackEmoji: '😊',
);

/// 每日心情选择器弹窗
class DailyMoodPicker extends StatelessWidget {
  final String? selectedImagePath;
  final Function(DailyMood) onSelect;

  const DailyMoodPicker({
    super.key,
    this.selectedImagePath,
    required this.onSelect,
  });

  static Future<DailyMood?> show({
    required BuildContext context,
    String? currentImagePath,
  }) {
    return showModalBottomSheet<DailyMood>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DailyMoodPicker(
        selectedImagePath: currentImagePath,
        onSelect: (mood) => Navigator.of(context).pop(mood),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _resolveColumnCount(
            maxWidth: constraints.maxWidth,
            textScale: textScale,
          );
          const spacing = 12.0;
          final tileWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;
          final minTileHeight = textScale >= 1.6
              ? 122.0
              : textScale >= 1.25
                  ? 110.0
                  : 96.0;

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.moodPickerTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionTitle.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.moodPickerSubtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final mood in dailyMoods)
                          SizedBox(
                            width: tileWidth,
                            child: _MoodOptionTile(
                              mood: mood,
                              isSelected: selectedImagePath == mood.imagePath,
                              minHeight: minTileHeight,
                              onTap: () => onSelect(mood),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

int _resolveColumnCount({
  required double maxWidth,
  required double textScale,
}) {
  if (maxWidth < 340 || textScale >= 1.6) {
    return 2;
  }
  if (maxWidth < 420 || textScale >= 1.25) {
    return 3;
  }
  return 4;
}

class _MoodOptionTile extends StatelessWidget {
  final DailyMood mood;
  final bool isSelected;
  final double minHeight;
  final VoidCallback onTap;

  const _MoodOptionTile({
    required this.mood,
    required this.isSelected,
    required this.minHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moodLabel = localizedMoodLabel(context, mood);

    return Semantics(
      button: true,
      selected: isSelected,
      label: moodLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? mood.color.withValues(alpha: 0.15)
                  : AppColors.bgInput,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: mood.color, width: 2)
                  : Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MoodIcon(mood: mood, size: 32),
                const SizedBox(height: 8),
                Text(
                  moodLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.tagLabel.copyWith(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? mood.color : AppColors.textSecondary,
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

String localizedMoodLabel(BuildContext context, DailyMood mood) {
  final l10n = AppLocalizations.of(context)!;
  switch (mood.imagePath) {
    case 'assets/images/moods/happy.png':
      return l10n.moodHappy;
    case 'assets/images/moods/calm.png':
      return l10n.moodCalm;
    case 'assets/images/moods/loved.png':
      return l10n.moodLoved;
    case 'assets/images/moods/sad.png':
      return l10n.moodSad;
    case 'assets/images/moods/annoyed.png':
      return l10n.moodAnnoyed;
    case 'assets/images/moods/anxious.png':
      return l10n.moodAnxious;
    case 'assets/images/moods/tired.png':
      return l10n.moodTired;
    case 'assets/images/moods/confused.png':
      return l10n.moodConfused;
    default:
      return mood.label;
  }
}

/// 获取指定日期的心情存储键
String getDailyMoodKey(DateTime date) {
  return 'daily_mood_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 根据图片路径获取 DailyMood 对象
DailyMood? getMoodByImagePath(String? imagePath) {
  if (imagePath == null) return null;
  try {
    return dailyMoods.firstWhere((mood) => mood.imagePath == imagePath);
  } catch (_) {
    return null;
  }
}

/// 心情图标组件 - 优先显示图片，加载失败时显示 emoji
class MoodIcon extends StatelessWidget {
  final DailyMood mood;
  final double size;

  const MoodIcon({
    super.key,
    required this.mood,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mood.imagePath,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          mood.fallbackEmoji,
          style: TextStyle(fontSize: size * 0.85),
        );
      },
    );
  }
}

/// 根据图片路径显示心情图标
class MoodIconByPath extends StatelessWidget {
  final String? imagePath;
  final double size;

  const MoodIconByPath({
    super.key,
    this.imagePath,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final mood = getMoodByImagePath(imagePath) ?? defaultMood;
    return MoodIcon(mood: mood, size: size);
  }
}
