/// 碎片记录页面
/// 显示所有快速记录，按日期分组，时间轴样式
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/record.dart';
import '../../../core/di/injection.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_state.dart';
import '../../bloc/record/record_event.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../../widgets/daily_mood_picker.dart';
import '../record_detail/record_detail_screen.dart';

// ============================================================
// Design Tokens - 统一的设计规范
// ============================================================

/// 字体大小 - 4级层次
class _FontSize {
  static const double display = 24.0;   // 页面标题
  static const double title = 16.0;     // 区块标题
  static const double body = 15.0;      // 正文内容
  static const double caption = 13.0;   // 辅助说明
  static const double label = 12.0;     // 标签文字
}

/// 间距 - 基于 4px 网格
class _Spacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// 颜色 - 统一色板
class _Colors {
  static const Color background = Color(0xFFFAF6F1);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFFC4A57B);
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF5D4E3C);
  static const Color textMuted = Color(0xFF8B7D6B);
  static const Color textHint = Color(0xFFAAAAAA);
  static const Color border = Color(0xFFE0D5C5);
  static const Color divider = Color(0xFFE8E0D5);
  static const Color cardBg = Color(0xFFF7F0E8);
}

// ============================================================

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
  final HiveDatabase _database = getIt<HiveDatabase>();
  final Map<String, String> _dailyMoods = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadDailyMoods();
  }

  void _loadRecords() {
    context.read<RecordBloc>().add(const RecordLoadList());
  }

  void _loadDailyMoods() {
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final key = getDailyMoodKey(date);
      final imagePath = _database.settingsBox.get(key) as String?;
      if (imagePath != null) {
        _dailyMoods[key] = imagePath;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleMoodTap(DateTime date) async {
    final key = getDailyMoodKey(date);
    final currentImagePath = _dailyMoods[key];

    final selectedMood = await DailyMoodPicker.show(
      context: context,
      currentImagePath: currentImagePath,
    );

    if (selectedMood != null) {
      await _database.settingsBox.put(key, selectedMood.imagePath);
      setState(() {
        _dailyMoods[key] = selectedMood.imagePath;
      });
    }
  }

  String _getDailyMoodImagePath(DateTime date) {
    final key = getDailyMoodKey(date);
    return _dailyMoods[key] ?? defaultMood.imagePath;
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
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题
            _buildHeader(),

            // 记录列表
            Expanded(
              child: BlocBuilder<RecordBloc, RecordState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_Colors.primary),
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
                    color: _Colors.primary,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        _Spacing.xl,
                        _Spacing.sm,
                        _Spacing.xl,
                        _Spacing.xxl,
                      ),
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

  /// 顶部标题栏
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _Spacing.xl,
        _Spacing.lg,
        _Spacing.xl,
        _Spacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '每日记录',
            style: TextStyle(
              color: _Colors.textPrimary,
              fontSize: _FontSize.display,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Colors.surface,
              borderRadius: BorderRadius.circular(_Spacing.md),
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
              color: _Colors.textMuted,
            ),
          ),
        ],
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
              borderRadius: BorderRadius.circular(_Spacing.xl),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 28,
              color: _Colors.primary,
            ),
          ),
          SizedBox(height: _Spacing.lg),
          Text(
            errorMessage ?? '加载失败',
            style: const TextStyle(
              color: _Colors.textMuted,
              fontSize: _FontSize.body,
              height: 1.4,
            ),
          ),
          SizedBox(height: _Spacing.xl),
          GestureDetector(
            onTap: _loadRecords,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _Spacing.xxl,
                vertical: _Spacing.md,
              ),
              decoration: BoxDecoration(
                color: _Colors.primary,
                borderRadius: BorderRadius.circular(_Spacing.xxl),
              ),
              child: const Text(
                '重试',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _FontSize.body,
                  fontWeight: FontWeight.w500,
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
        SizedBox(height: _Spacing.xl),

        // 日期标题行
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 日期指示条
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _Colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: _Spacing.sm),
            Text(
              _formatDateTitle(date),
              style: const TextStyle(
                fontSize: _FontSize.title,
                fontWeight: FontWeight.w600,
                color: _Colors.textPrimary,
                letterSpacing: -0.2,
                height: 1.3,
              ),
            ),
            SizedBox(width: _Spacing.sm),
            Text(
              _getDateLabel(date),
              style: const TextStyle(
                fontSize: _FontSize.caption,
                color: _Colors.textHint,
                height: 1.3,
              ),
            ),
          ],
        ),

        SizedBox(height: _Spacing.lg),

        // 每日心情概览
        if (records.isNotEmpty) _buildDailyMoodCard(date, records),

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

  /// 每日心情卡片
  Widget _buildDailyMoodCard(DateTime date, List<Record> records) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_Spacing.md),
      margin: EdgeInsets.only(bottom: _Spacing.lg),
      decoration: BoxDecoration(
        color: _Colors.cardBg,
        borderRadius: BorderRadius.circular(_Spacing.md),
      ),
      child: Row(
        children: [
          // 心情图标（可点击）
          GestureDetector(
            onTap: () => _handleMoodTap(date),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _Colors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: MoodIconByPath(
                  imagePath: _getDailyMoodImagePath(date),
                  size: 22,
                ),
              ),
            ),
          ),
          SizedBox(width: _Spacing.md),
          Expanded(
            child: GestureDetector(
              onTap: () => _handleMoodTap(date),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日心情',
                    style: TextStyle(
                      fontSize: _FontSize.caption,
                      fontWeight: FontWeight.w500,
                      color: _Colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: _Spacing.xs),
                  Text(
                    '共 ${records.length} 条记录 · 点击修改心情',
                    style: const TextStyle(
                      fontSize: _FontSize.label,
                      color: _Colors.textHint,
                      height: 1.3,
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

  /// 构建时间轴样式的单条记录
  Widget _buildTimelineItem(Record record, bool isLast) {
    final hasNVC = record.nvc != null;
    final hasMoods = record.moods != null && record.moods!.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // 时间
                Text(
                  _formatTime(record.createdAt),
                  style: const TextStyle(
                    fontSize: _FontSize.caption,
                    fontWeight: FontWeight.w500,
                    color: _Colors.textHint,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: _Spacing.sm),
                // 圆点
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _Colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                // 连接线
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: EdgeInsets.symmetric(vertical: _Spacing.sm),
                      color: _Colors.divider,
                    ),
                  )
                else
                  SizedBox(height: _Spacing.lg),
              ],
            ),
          ),

          SizedBox(width: _Spacing.md),

          // 右侧卡片
          Expanded(
            child: GestureDetector(
              onTap: () => _handleRecordTap(record),
              child: Container(
                margin: EdgeInsets.only(bottom: _Spacing.md),
                padding: EdgeInsets.all(_Spacing.lg),
                decoration: BoxDecoration(
                  color: _Colors.surface,
                  borderRadius: BorderRadius.circular(_Spacing.md),
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
                    // 内容
                    Text(
                      record.transcription,
                      style: const TextStyle(
                        fontSize: _FontSize.body,
                        color: _Colors.textPrimary,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 标签
                    if (hasNVC && record.nvc!.feelings.isNotEmpty) ...[
                      SizedBox(height: _Spacing.md),
                      Wrap(
                        spacing: _Spacing.sm,
                        runSpacing: _Spacing.sm,
                        children: record.nvc!.feelings.take(3).map((feeling) {
                          return _buildMoodTag(feeling.feeling);
                        }).toList(),
                      ),
                    ] else if (hasMoods) ...[
                      SizedBox(height: _Spacing.md),
                      Wrap(
                        spacing: _Spacing.sm,
                        runSpacing: _Spacing.sm,
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

  /// 构建情绪标签
  Widget _buildMoodTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _Spacing.sm + 2,
        vertical: _Spacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _Colors.border,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: _FontSize.label,
          color: _Colors.textMuted,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: _Spacing.xxxl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EBE0),
              borderRadius: BorderRadius.circular(_Spacing.lg),
            ),
            child: const Icon(
              Icons.edit_note_outlined,
              size: 26,
              color: Color(0xFFB8ADA0),
            ),
          ),
          SizedBox(height: _Spacing.md),
          const Text(
            '暂无记录',
            style: TextStyle(
              fontSize: _FontSize.body,
              color: _Colors.textHint,
              height: 1.4,
            ),
          ),
          SizedBox(height: _Spacing.lg),
          GestureDetector(
            onTap: widget.onNavigateToHome,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _Spacing.xl,
                vertical: _Spacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: _Colors.surface,
                borderRadius: BorderRadius.circular(_Spacing.xl),
                border: Border.all(
                  color: _Colors.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add,
                    size: 16,
                    color: _Colors.textMuted,
                  ),
                  SizedBox(width: _Spacing.sm),
                  const Text(
                    '开始记录',
                    style: TextStyle(
                      fontSize: _FontSize.caption,
                      color: _Colors.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
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
}
