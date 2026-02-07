/// 碎片记录页面
/// 显示所有快速记录，按日期分组
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

  /// 处理记录点击事件
  void _handleRecordTap(Record record) async {
    // 如果是NVC模式的记录，显示NVC确认弹窗
    if (record.nvc != null) {
      final result = await NVCConfirmationModal.show(
        context: context,
        initialAnalysis: record.nvc!,
        transcription: record.transcription,
        onRevert: () {
          // TODO: 还原为仅记录模式
        },
      );
      // 如果是删除操作，删除记录
      if (result?.action == NVCModalAction.delete) {
        context.read<RecordBloc>().add(
          RecordDelete(id: record.id),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录已删除')),
        );
      }
      // 弹窗关闭后刷新列表
      _loadRecords();
    } else {
      // 否则打开记录详情页面
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordDetailScreen(record: record),
        ),
      );
      // 详情页关闭后刷新列表
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '每日记录',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: const [],
      ),
      body: BlocBuilder<RecordBloc, RecordState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
              ),
            );
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.errorMessage ?? '加载失败',
                    style: const TextStyle(
                      color: Color(0xFF8B7D6B),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loadRecords,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE8DED0),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      '重试',
                      style: TextStyle(
                        color: Color(0xFF5D4E3C),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 按日期分组记录
          final groupedRecords = _groupRecordsByDate(state.records);
          // 无记录时仅显示当天卡片；有记录时只展示有记录的日期，避免空白多天列表
          final dateRange = state.isEmpty ? _getTodayOnly() : _getDatesWithRecords(groupedRecords);

          return RefreshIndicator(
            onRefresh: () async {
              _loadRecords();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: dateRange.length,
              itemBuilder: (context, index) {
                final date = dateRange[index];
                final records = groupedRecords[date] ?? [];

                return _buildDateCard(context, date, records);
              },
            ),
          );
        },
      ),
    );
  }

  /// 获取最近7天的日期
  List<DateTime> _getLast7Days() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: index));
      return DateTime(date.year, date.month, date.day);
    });
  }

  /// 仅返回当天日期
  List<DateTime> _getTodayOnly() {
    final now = DateTime.now();
    return [DateTime(now.year, now.month, now.day)];
  }

  /// 仅返回有记录的日期（按时间倒序）
  List<DateTime> _getDatesWithRecords(Map<DateTime, List<Record>> groupedRecords) {
    final dates = groupedRecords.keys.toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  /// 按日期分组记录
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

    // 按创建时间排序每天的记录
    grouped.forEach((key, value) {
      value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    return grouped;
  }

  /// 构建日期卡片
  Widget _buildDateCard(BuildContext context, DateTime date, List<Record> records) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTitle(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDateLabel(date),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                  onPressed: () {
                    // TODO: 显示更多选项
                  },
                ),
              ],
            ),
          ),

          // 记录列表或空状态
          if (records.isEmpty)
            _buildEmptyDateContent(context)
          else
            ...records.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (index > 0)
                    Divider(
                      color: Colors.grey[100],
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  _buildRecordItem(context, record),
                ],
              );
            }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 构建空状态内容
  Widget _buildEmptyDateContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: TextButton(
          onPressed: widget.onNavigateToHome,
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFF8F6F3),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 8),
              Text(
                '暂无内容，写写',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建单条记录
  Widget _buildRecordItem(BuildContext context, Record record) {
    final hasNVC = record.nvc != null;
    final hasMoods = record.moods != null && record.moods!.isNotEmpty;

    return GestureDetector(
      onTap: () => _handleRecordTap(record),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间
            Text(
              _formatTime(record.createdAt),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 12),

            // NVC标签（如果有）
            if (hasNVC && record.nvc!.feelings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.nvc!.feelings.map((feeling) {
                    return _buildEmotionTag(
                      feeling.feeling,
                      _getEmotionColor(feeling.feeling),
                    );
                  }).toList(),
                ),
              )
            else if (hasMoods)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.moods!.map((mood) {
                    return _buildEmotionTag(
                      mood,
                      _getEmotionColor(mood),
                    );
                  }).toList(),
                ),
              ),

            // 记录内容
            Text(
              record.transcription,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4A4A4A),
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建情绪标签
  Widget _buildEmotionTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取情绪对应的颜色
  Color _getEmotionColor(String emotion) {
    // 积极/快乐类 - 橙色
    if (emotion.contains('愉悦') ||
        emotion.contains('开心') ||
        emotion.contains('兴奋') ||
        emotion.contains('喜悦') ||
        emotion.contains('快乐') ||
        emotion.contains('满足')) {
      return const Color(0xFFFF9500);
    }
    // 焦虑/担忧类 - 蓝色
    else if (emotion.contains('焦虑') ||
        emotion.contains('担心') ||
        emotion.contains('紧张') ||
        emotion.contains('害怕') ||
        emotion.contains('不安')) {
      return const Color(0xFF007AFF);
    }
    // 平静/放松类 - 绿色
    else if (emotion.contains('平静') ||
        emotion.contains('放松') ||
        emotion.contains('安宁') ||
        emotion.contains('舒适') ||
        emotion.contains('宁静')) {
      return const Color(0xFF34C759);
    }
    // 愤怒/烦躁类 - 红色
    else if (emotion.contains('愤怒') ||
        emotion.contains('生气') ||
        emotion.contains('烦躁') ||
        emotion.contains('恼火') ||
        emotion.contains('不满')) {
      return const Color(0xFFFF3B30);
    }
    // 悲伤/失落类 - 紫色
    else if (emotion.contains('悲伤') ||
        emotion.contains('难过') ||
        emotion.contains('失落') ||
        emotion.contains('沮丧') ||
        emotion.contains('伤心')) {
      return const Color(0xFFAF52DE);
    }
    // 好奇/探索类 - 青色
    else if (emotion.contains('好奇') ||
        emotion.contains('探索') ||
        emotion.contains('求知') ||
        emotion.contains('疑惑')) {
      return const Color(0xFF5AC8FA);
    }
    // 思考/专注类 - 靛蓝色
    else if (emotion.contains('思考') ||
        emotion.contains('专注') ||
        emotion.contains('沉思') ||
        emotion.contains('冥想')) {
      return const Color(0xFF5856D6);
    }
    // 关注/在意类 - 黄色
    else if (emotion.contains('关注') ||
        emotion.contains('在意') ||
        emotion.contains('重视') ||
        emotion.contains('关心')) {
      return const Color(0xFFFFCC00);
    }
    // 感激/感动类 - 粉色
    else if (emotion.contains('感激') ||
        emotion.contains('感动') ||
        emotion.contains('感恩') ||
        emotion.contains('温暖')) {
      return const Color(0xFFFF2D55);
    }
    // 疲惫/困倦类 - 棕色
    else if (emotion.contains('疲惫') ||
        emotion.contains('困倦') ||
        emotion.contains('劳累') ||
        emotion.contains('疲劳')) {
      return const Color(0xFFA2845E);
    }
    // 其他未匹配的情绪 - 使用一致的随机颜色
    else {
      return _getConsistentColorForText(emotion);
    }
  }

  /// 为文本生成一致的颜色（基于字符串哈希）
  Color _getConsistentColorForText(String text) {
    // 预定义的柔和色值池
    const colorPalette = [
      Color(0xFF8E8E93), // 灰色
      Color(0xFF32ADE6), // 浅蓝
      Color(0xFF34C759), // 浅绿
      Color(0xFFFF9500), // 橙色
      Color(0xFFAF52DE), // 紫色
      Color(0xFF5AC8FA), // 青色
      Color(0xFFFFCC00), // 黄色
      Color(0xFFFF6B6B), // 浅红
      Color(0xFF4ECDC4), // 蒂芙尼蓝
      Color(0xFF95E1D3), // 薄荷绿
    ];

    // 基于文本内容计算哈希值
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }
    hash = hash.abs();

    // 使用哈希值选择颜色
    return colorPalette[hash % colorPalette.length];
  }

  /// 格式化日期标题
  String _formatDateTitle(DateTime date) {
    final weekDays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return '${date.month}月${date.day}日 ${weekDays[date.weekday - 1]}';
  }

  /// 获取日期标签（今天/昨天）
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return '今天';
    } else if (date == yesterday) {
      return '昨天';
    }
    return '';
  }

  /// 格式化时间
  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }
}
