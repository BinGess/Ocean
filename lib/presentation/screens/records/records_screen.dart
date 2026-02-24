/// 碎片记录页面
/// 显示所有快速记录，按日期分组，时间轴样式
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/record.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_state.dart';
import '../../bloc/record/record_event.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../record_detail/record_detail_screen.dart';

class RecordsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const RecordsScreen({
    super.key,
    this.onNavigateToHome,
  });

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    context.read<RecordBloc>().add(const RecordLoadList());
  }

  void _handleRecordTap(Record record) async {
    if (record.nvc != null) {
      final result = await NVCConfirmationModal.show(
        context: context,
        initialAnalysis: record.nvc!,
        transcription: record.transcription,
        onRevert: () {},
        record: record,
      );
      if (result?.action == NVCModalAction.delete) {
        context.read<RecordBloc>().add(RecordDelete(id: record.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录已删除')),
        );
      }
      _loadRecords();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordDetailScreen(record: record),
        ),
      );
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '每日记录',
                    style: TextStyle(
                      color: Color(0xFF2C2C2C),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  // 可以放置筛选/搜索按钮
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF8B7D6B),
                    ),
                  ),
                ],
              ),
            ),

            // 记录列表
            Expanded(
              child: BlocBuilder<RecordBloc, RecordState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
                      ),
                    );
                  }

                  if (state.hasError) {
                    return _buildErrorState(state.errorMessage);
                  }

                  final groupedRecords = _groupRecordsByDate(state.records);
                  final dateRange = state.isEmpty
                      ? _getTodayOnly()
                      : _getDatesWithRecords(groupedRecords);

                  return RefreshIndicator(
                    onRefresh: () async => _loadRecords(),
                    color: const Color(0xFFC4A57B),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: dateRange.length,
                      itemBuilder: (context, index) {
                        final date = dateRange[index];
                        final records = groupedRecords[date] ?? [];
                        return _buildDaySection(date, records);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 28,
              color: Color(0xFFC4A57B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage ?? '加载失败',
            style: const TextStyle(
              color: Color(0xFF8B7D6B),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadRecords,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFC4A57B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                '重试',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建每天的记录区块
  Widget _buildDaySection(DateTime date, List<Record> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // 日期标题行
        Row(
          children: [
            // 日期指示条
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFC4A57B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatDateTitle(date),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C2C2C),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getDateLabel(date),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 每日总结占位区（后续可扩展）
        if (records.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4A57B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFFC4A57B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日情绪概览',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D4E3C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '共 ${records.length} 条记录',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 记录列表（时间轴样式）
        if (records.isEmpty)
          _buildEmptyState()
        else
          ...records.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            final isLast = index == records.length - 1;
            return _buildTimelineItem(record, isLast);
          }),
      ],
    );
  }

  /// 构建时间轴样式的单条记录
  Widget _buildTimelineItem(Record record, bool isLast) {
    final hasNVC = record.nvc != null;
    final hasMoods = record.moods != null && record.moods!.isNotEmpty;

    // 统一使用暖橙色
    const dotColor = Color(0xFFC4A57B);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 52,
            child: Column(
              children: [
                // 时间
                Text(
                  _formatTime(record.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 8),
                // 圆点
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                // 连接线
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: const Color(0xFFE8E0D5),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 右侧卡片
          Expanded(
            child: GestureDetector(
              onTap: () => _handleRecordTap(record),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 内容（上方）
                    Text(
                      record.transcription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF3C3C3C),
                        height: 1.6,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 标签（下方）- 统一中性描边样式
                    if (hasNVC && record.nvc!.feelings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: record.nvc!.feelings.take(3).map((feeling) {
                          return _buildMoodTag(feeling.feeling);
                        }).toList(),
                      ),
                    ] else if (hasMoods) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: record.moods!.take(3).map((mood) {
                          return _buildMoodTag(mood);
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建情绪标签 - 统一中性描边样式
  Widget _buildMoodTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE0D5C5),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF8B7D6B),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EBE0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.edit_note_outlined,
              size: 26,
              color: Color(0xFFB8ADA0),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '暂无记录',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onNavigateToHome,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE0D5C5),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 16,
                    color: Color(0xFF8B7D6B),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '开始记录',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5D4E3C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === 辅助方法 ===

  List<DateTime> _getTodayOnly() {
    final now = DateTime.now();
    return [DateTime(now.year, now.month, now.day)];
  }

  List<DateTime> _getDatesWithRecords(Map<DateTime, List<Record>> groupedRecords) {
    final dates = groupedRecords.keys.toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  Map<DateTime, List<Record>> _groupRecordsByDate(List<Record> records) {
    final grouped = <DateTime, List<Record>>{};

    for (final record in records) {
      final date = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(record);
    }

    grouped.forEach((key, value) {
      value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    return grouped;
  }

  String _formatDateTitle(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return '今天';
    } else if (date == yesterday) {
      return '昨天';
    }
    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekDays[date.weekday - 1];
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  Color _getEmotionColor(String emotion) {
    if (emotion.contains('愉悦') ||
        emotion.contains('开心') ||
        emotion.contains('兴奋') ||
        emotion.contains('喜悦') ||
        emotion.contains('快乐') ||
        emotion.contains('满足')) {
      return const Color(0xFFFF9500);
    } else if (emotion.contains('焦虑') ||
        emotion.contains('担心') ||
        emotion.contains('紧张') ||
        emotion.contains('害怕') ||
        emotion.contains('不安')) {
      return const Color(0xFF5AC8FA);
    } else if (emotion.contains('平静') ||
        emotion.contains('放松') ||
        emotion.contains('安宁') ||
        emotion.contains('舒适') ||
        emotion.contains('宁静')) {
      return const Color(0xFF34C759);
    } else if (emotion.contains('愤怒') ||
        emotion.contains('生气') ||
        emotion.contains('烦躁') ||
        emotion.contains('恼火') ||
        emotion.contains('不满')) {
      return const Color(0xFFFF6B6B);
    } else if (emotion.contains('悲伤') ||
        emotion.contains('难过') ||
        emotion.contains('失落') ||
        emotion.contains('沮丧') ||
        emotion.contains('伤心') ||
        emotion.contains('低落')) {
      return const Color(0xFF8E8CD8);
    } else if (emotion.contains('疲惫') ||
        emotion.contains('困倦') ||
        emotion.contains('倦怠') ||
        emotion.contains('疲劳')) {
      return const Color(0xFFA2845E);
    } else {
      return _getConsistentColorForText(emotion);
    }
  }

  Color _getConsistentColorForText(String text) {
    const colorPalette = [
      Color(0xFF8E8E93),
      Color(0xFF5AC8FA),
      Color(0xFF34C759),
      Color(0xFFFF9500),
      Color(0xFF8E8CD8),
      Color(0xFFFF6B6B),
      Color(0xFFFFC107),
      Color(0xFF4ECDC4),
    ];

    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }
    hash = hash.abs();

    return colorPalette[hash % colorPalette.length];
  }
}
