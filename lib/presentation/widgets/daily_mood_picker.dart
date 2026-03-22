import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
  DailyMood(imagePath: 'assets/images/moods/happy.png', label: '开心', color: Color(0xFFFFD93D), fallbackEmoji: '😊'),
  DailyMood(imagePath: 'assets/images/moods/calm.png', label: '平静', color: Color(0xFF6BCB77), fallbackEmoji: '😌'),
  DailyMood(imagePath: 'assets/images/moods/loved.png', label: '幸福', color: Color(0xFFFF6B6B), fallbackEmoji: '🥰'),
  DailyMood(imagePath: 'assets/images/moods/sad.png', label: '低落', color: Color(0xFF748DA6), fallbackEmoji: '😔'),
  DailyMood(imagePath: 'assets/images/moods/annoyed.png', label: '烦躁', color: Color(0xFFFF8B4D), fallbackEmoji: '😤'),
  DailyMood(imagePath: 'assets/images/moods/anxious.png', label: '焦虑', color: Color(0xFF9B7EDE), fallbackEmoji: '😰'),
  DailyMood(imagePath: 'assets/images/moods/tired.png', label: '疲惫', color: Color(0xFFB4B4B4), fallbackEmoji: '😴'),
  DailyMood(imagePath: 'assets/images/moods/confused.png', label: '困惑', color: Color(0xFF4ECDC4), fallbackEmoji: '🤔'),
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
      backgroundColor: Colors.transparent,
      builder: (context) => DailyMoodPicker(
        selectedImagePath: currentImagePath,
        onSelect: (mood) => Navigator.of(context).pop(mood),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          const Text(
            '今天心情如何？',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择一个表情来记录今天的心情',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),

          // 心情网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: dailyMoods.length,
            itemBuilder: (context, index) {
              final mood = dailyMoods[index];
              final isSelected = selectedImagePath == mood.imagePath;

              return GestureDetector(
                onTap: () => onSelect(mood),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? mood.color.withValues(alpha: 0.15)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: mood.color, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MoodIcon(mood: mood, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        mood.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? mood.color
                              : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
