import 'package:flutter/material.dart';
import '../../domain/entities/record.dart';

class ProcessingChoiceModal extends StatelessWidget {
  final String transcription;
  final Function(ProcessingMode) onSelect;
  final VoidCallback? onCancel;
  final VoidCallback? onNVCInsight;

  const ProcessingChoiceModal({
    super.key,
    required this.transcription,
    required this.onSelect,
    this.onCancel,
    this.onNVCInsight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '录音完成',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    size: 24,
                    color: Color(0xFF8B7D6B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 转写文本预览
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: const BoxConstraints(minHeight: 60),
            child: Center(
              child: Text(
                transcription.isEmpty || transcription == '正在转写中...'
                    ? '正在转写中...'
                    : transcription,
                style: TextStyle(
                  fontSize: 15,
                  color: transcription.isEmpty || transcription == '正在转写中...'
                      ? const Color(0xFFB8ADA0)
                      : const Color(0xFF5D4E3C),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 选项标题
          const Text(
            '选择处理方式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4E3C),
            ),
          ),

          const SizedBox(height: 16),

          // 选项卡片（2列布局）
          Row(
            children: [
              // NVC 分析
              Expanded(
                child: _ProcessingOption(
                  icon: Icons.lightbulb_outline,
                  title: 'NVC 分析',
                  description: '完整的情绪分析',
                  iconColor: const Color(0xFFB794F6), // 紫色
                  backgroundColor: const Color(0xFFF3EBFF),
                  onTap: onNVCInsight ?? () {
                    onSelect(ProcessingMode.withNVC);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // 仅记录文本
              Expanded(
                child: _ProcessingOption(
                  icon: Icons.description_outlined,
                  title: '仅记录文本',
                  description: '不做进一步分析',
                  iconColor: const Color(0xFF7DBEF5), // 蓝色
                  backgroundColor: const Color(0xFFE8F4FD),
                  onTap: () {
                    onSelect(ProcessingMode.onlyRecord);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  static Future<ProcessingMode?> show({
    required BuildContext context,
    required String transcription,
  }) {
    return showModalBottomSheet<ProcessingMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProcessingChoiceModal(
        transcription: transcription,
        onSelect: (mode) => Navigator.of(context).pop(mode),
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _ProcessingOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ProcessingOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8DED0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              // 标题
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // 描述
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB8ADA0),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
