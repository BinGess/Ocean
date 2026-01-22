/// 快速笔记卡片组件
/// 显示单个记录的卡片

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/record.dart';
import '../../core/theme/app_colors.dart';

class QuickNoteCard extends StatelessWidget {
  final Record record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const QuickNoteCard({
    super.key,
    required this.record,
    this.onTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：时间和操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 时间
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(record.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (record.duration != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.mic,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${record.duration!.toInt()}s',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // 操作按钮
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: onEdit,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 转写文本
              Text(
                record.transcription,
                style: theme.textTheme.bodyLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // 情绪标签
              if (record.moods != null && record.moods!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.moods!.map((mood) {
                    return _MoodChip(mood: mood);
                  }).toList(),
                ),
              ],

              // NVC 分析摘要
              if (record.nvc != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NVC 分析已完成',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],

              // 需要标签
              if (record.needs != null && record.needs!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.needs!.take(3).map((need) {
                    return _NeedChip(need: need);
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 情绪标签
class _MoodChip extends StatelessWidget {
  final String mood;

  const _MoodChip({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '😊',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            mood,
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 需要标签
class _NeedChip extends StatelessWidget {
  final String need;

  const _NeedChip({required this.need});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sage.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.sage.withOpacity(0.3),
        ),
      ),
      child: Text(
        need,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.sage,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
