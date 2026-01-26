/// 处理选择模态框
/// 录音完成后选择处理方式：仅记录、添加情绪、NVC分析、NVC洞察

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
    final theme = Theme.of(context);
    print('ProcessingChoiceModal: Building with transcription: $transcription');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '录音完成',
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 转写文本预览
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(
                transcription,
                style: theme.textTheme.bodyMedium,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 选项标题
          Text(
            '选择处理方式',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          // 选项 1：仅记录
          _ProcessingOption(
            icon: Icons.text_snippet,
            title: '仅记录文本',
            description: '保存转写文本，不做进一步分析',
            color: Colors.blue,
            onTap: () {
              onSelect(ProcessingMode.onlyRecord);
            },
          ),

          const SizedBox(height: 12),

          // 选项 2：添加情绪
          _ProcessingOption(
            icon: Icons.mood,
            title: '添加情绪',
            description: '标记当前的情绪状态',
            color: Colors.orange,
            onTap: () {
              onSelect(ProcessingMode.withMood);
            },
          ),

          const SizedBox(height: 12),

          // 选项 3：NVC 分析
          _ProcessingOption(
            icon: Icons.psychology,
            title: 'NVC 分析',
            description: '完整的情绪分析（观察-感受-需要-请求）',
            color: Colors.purple,
            onTap: () {
              onSelect(ProcessingMode.withNVC);
            },
          ),

          const SizedBox(height: 12),

          // 选项 4：NVC 洞察（AI智能体）
          if (onNVCInsight != null)
            _ProcessingOption(
              icon: Icons.auto_awesome,
              title: 'NVC 洞察',
              description: 'AI智能体深度分析（观察-感受-需要-请求）',
              color: Colors.deepPurple,
              onTap: () {
                onNVCInsight!();
              },
            ),

          const SizedBox(height: 24),
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
  final Color color;
  final VoidCallback onTap;

  const _ProcessingOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // 文本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 箭头
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
