/// 碎片记录页面
/// 显示所有快速记录，按日期分组，时间轴样式
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/daily_summary.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/daily_summary_service.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../l10n/app_localizations.dart';
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
  static const double display = 24.0; // 页面标题
  static const double title = 16.0; // 区块标题
  static const double body = 15.0; // 正文内容
  static const double caption = 13.0; // 辅助说明
  static const double label = 12.0; // 标签文字
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
  final DailySummaryService _dailySummaryService = getIt<DailySummaryService>();
  final Map<String, String> _dailyMoods = {};
  final Map<String, DailySummary> _dailySummaries = {};
  final Set<String> _generatingSummaries = {};
  bool _isRefreshingDailySummary = false;
  StreamSubscription<DailySummaryUpdate>? _dailySummarySubscription;

  @override
  void initState() {
    super.initState();
    _dailySummarySubscription = _dailySummaryService.summaryUpdates.listen((
      update,
    ) {
      if (!mounted) return;
      setState(() {
        _dailySummaries[update.key] = update.summary;
        _generatingSummaries.remove(update.key);
      });
    });
    _loadRecords();
    _loadDailyMoods();
  }

  @override
  void dispose() {
    _dailySummarySubscription?.cancel();
    super.dispose();
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

  /// 加载日总结并在需要时触发生成
  void _loadDailySummaries(Map<DateTime, List<Record>> groupedRecords) {
    for (final entry in groupedRecords.entries) {
      final date = entry.key;
      final records = entry.value;
      final summaryKey = getDailySummaryKey(date);

      // 加载已缓存的日总结
      final existingSummary = _dailySummaryService.getDailySummary(date);
      if (existingSummary != null) {
        _dailySummaries[summaryKey] = existingSummary;
      }

      // 检查是否需要生成/重新生成
      if (_dailySummaryService.needsRegeneration(date, records.length) &&
          !_generatingSummaries.contains(summaryKey)) {
        _generateDailySummary(date, records);
      }
    }
  }

  /// 异步生成日总结
  void _generateDailySummary(DateTime date, List<Record> records) {
    final summaryKey = getDailySummaryKey(date);
    _generatingSummaries.add(summaryKey);

    _dailySummaryService.generateDailySummaryDebounced(
      date,
      records,
      onComplete: (summary) {
        if (!mounted) return;
        setState(() {
          _generatingSummaries.remove(summaryKey);
        });
      },
    );
  }

  /// 获取日期的日总结
  DailySummary? _getDailySummary(DateTime date) {
    final summaryKey = getDailySummaryKey(date);
    return _dailySummaries[summaryKey];
  }

  /// 检查是否正在生成日总结
  bool _isGeneratingSummary(DateTime date) {
    final summaryKey = getDailySummaryKey(date);
    return _generatingSummaries.contains(summaryKey);
  }

  /// 强制刷新最近一天的日总结（忽略 userOverridden）
  Future<void> _forceRefreshLatestDailySummary() async {
    if (_isRefreshingDailySummary) return;

    final records = context.read<RecordBloc>().state.records;
    final groupedRecords = _groupRecordsByDate(records);
    final dates = _getDatesWithRecords(groupedRecords);

    DateTime? targetDate;
    List<Record> targetRecords = const [];
    for (final date in dates) {
      final dayRecords = groupedRecords[date] ?? const [];
      if (dayRecords.length >= DailySummaryService.minRecordCount) {
        targetDate = date;
        targetRecords = dayRecords;
        break;
      }
    }

    if (targetDate == null) {
      _loadRecords();
      return;
    }

    final summaryKey = getDailySummaryKey(targetDate);
    setState(() {
      _isRefreshingDailySummary = true;
      _generatingSummaries.add(summaryKey);
    });

    try {
      final summary = await _dailySummaryService.generateDailySummary(
        targetDate,
        targetRecords,
        force: true,
      );
      if (!mounted) return;
      setState(() {
        if (summary != null) {
          _dailySummaries[summaryKey] = summary;
        }
        _generatingSummaries.remove(summaryKey);
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.refreshFailed)),
      );
      setState(() {
        _generatingSummaries.remove(summaryKey);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingDailySummary = false;
        });
      }
    }
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
      // 标记用户已手动设置心情，防止 AI 覆盖
      await _dailySummaryService.markUserOverridden(date);
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

      if (!mounted) return;

      if (result?.action == NVCModalAction.delete) {
        context.read<RecordBloc>().add(RecordDelete(id: record.id));
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.recordDeleted)),
        );
      }
      _loadRecords();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordDetailScreen(record: record),
        ),
      );
      if (!mounted) return;
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.warmPageBackgroundGradient,
            stops: [0.0, 0.62, 1.0],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _Colors.primary),
                            ),
                          );
                        }

                        if (state.hasError) {
                          return _buildErrorState(state.errorMessage);
                        }

                        final groupedRecords =
                            _groupRecordsByDate(state.records);
                        final dateRange = state.isEmpty
                            ? _getTodayOnly()
                            : _getDatesWithRecords(groupedRecords);

                        // 加载日总结
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadDailySummaries(groupedRecords);
                        });

                        return RefreshIndicator(
                          onRefresh: () async => _loadRecords(),
                          color: _Colors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
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
          ],
        ),
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _Spacing.xl,
        _Spacing.lg,
        _Spacing.xl,
        _Spacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.dailyRecords,
            style: const TextStyle(
              color: _Colors.textPrimary,
              fontSize: _FontSize.display,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isRefreshingDailySummary
                  ? null
                  : _forceRefreshLatestDailySummary,
              borderRadius: BorderRadius.circular(_Spacing.md),
              splashColor: _Colors.primary.withValues(alpha: 0.18),
              highlightColor: _Colors.primary.withValues(alpha: 0.10),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _Colors.surface,
                  borderRadius: BorderRadius.circular(_Spacing.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _isRefreshingDailySummary
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _Colors.primary.withValues(alpha: 0.85),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: _Colors.primary,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    final l10n = AppLocalizations.of(context)!;
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
          const SizedBox(height: _Spacing.lg),
          Text(
            errorMessage ?? l10n.loadFailed,
            style: const TextStyle(
              color: _Colors.textMuted,
              fontSize: _FontSize.body,
              height: 1.4,
            ),
          ),
          const SizedBox(height: _Spacing.xl),
          GestureDetector(
            onTap: _loadRecords,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _Spacing.xxl,
                vertical: _Spacing.md,
              ),
              decoration: BoxDecoration(
                color: _Colors.primary,
                borderRadius: BorderRadius.circular(_Spacing.xxl),
              ),
              child: Text(
                l10n.retry,
                style: AppTypography.actionLabel.copyWith(
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
        const SizedBox(height: _Spacing.xl),

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
            const SizedBox(width: _Spacing.sm),
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
            const SizedBox(width: _Spacing.sm),
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

        const SizedBox(height: _Spacing.lg),

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
    final l10n = AppLocalizations.of(context)!;
    final dailySummary = _getDailySummary(date);
    final isGenerating = _isGeneratingSummary(date);
    final moodKey = getDailyMoodKey(date);
    final hasUserSelectedMood = _dailyMoods.containsKey(moodKey);

    // 主心情文案始终来自心情图标映射，不被 AI 关键词覆盖
    String displayMoodImagePath = _getDailyMoodImagePath(date);

    if (!hasUserSelectedMood &&
        dailySummary != null &&
        !dailySummary.userOverridden) {
      displayMoodImagePath = dailySummary.recommendedMoodImagePath;
    }
    final displayMood = getMoodByImagePath(displayMoodImagePath) ?? defaultMood;
    final displayMoodLabel = displayMood.label;
    final aiMoodWord = dailySummary?.moodWord.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_Spacing.md),
      margin: const EdgeInsets.only(bottom: _Spacing.lg),
      decoration: BoxDecoration(
        color: _Colors.cardBg,
        borderRadius: BorderRadius.circular(_Spacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: MoodIconByPath(
                      imagePath: displayMoodImagePath,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _Spacing.md),
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleMoodTap(date),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayMoodLabel,
                            style: const TextStyle(
                              fontSize: _FontSize.caption,
                              fontWeight: FontWeight.w600,
                              color: _Colors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          // AI 返回的情绪关键词标签（放在“心情”右侧）
                          if (dailySummary != null &&
                              aiMoodWord.isNotEmpty) ...[
                            const SizedBox(width: _Spacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _Spacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _Colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                aiMoodWord,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _Colors.primary,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                          // 正在生成中指示
                          if (isGenerating) ...[
                            const SizedBox(width: _Spacing.xs),
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _Colors.primary.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: _Spacing.xs),
                      if (dailySummary != null &&
                          dailySummary.oneSentence.isNotEmpty)
                        Text(
                          dailySummary.oneSentence,
                          style: const TextStyle(
                            fontSize: _FontSize.label,
                            color: _Colors.textHint,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          l10n.recordsCount(records.length),
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
        ],
      ),
    );
  }

  /// 构建时间轴样式的单条记录
  Widget _buildTimelineItem(Record record, bool isLast) {
    final moodTags = _normalizeMoodTags(record.moods);
    final hasMoods = moodTags.isNotEmpty;

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
                const SizedBox(height: _Spacing.sm),
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
                      margin: const EdgeInsets.symmetric(vertical: _Spacing.sm),
                      color: _Colors.divider,
                    ),
                  )
                else
                  const SizedBox(height: _Spacing.lg),
              ],
            ),
          ),

          const SizedBox(width: _Spacing.md),

          // 右侧卡片
          Expanded(
            child: GestureDetector(
              onTap: () => _handleRecordTap(record),
              child: Container(
                margin: const EdgeInsets.only(bottom: _Spacing.lg),
                padding: const EdgeInsets.all(_Spacing.md),
                decoration: BoxDecoration(
                  color: _Colors.surface,
                  borderRadius: BorderRadius.circular(_Spacing.lg),
                  border: Border.all(color: _Colors.border, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 转写内容
                    if (record.transcription.isNotEmpty)
                      Text(
                        record.transcription,
                        style: const TextStyle(
                          fontSize: _FontSize.body,
                          color: _Colors.textPrimary,
                          height: 1.6,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // 心情标签
                    if (hasMoods) ...[
                      const SizedBox(height: _Spacing.sm),
                      Wrap(
                        spacing: _Spacing.xs,
                        runSpacing: _Spacing.xs,
                        children: moodTags.map((mood) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _Spacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _Colors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _Colors.border,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              mood,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _Colors.textSecondary,
                              ),
                            ),
                          );
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

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: _Spacing.xxxl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.edit_note,
              size: 48,
              color: _Colors.textHint.withValues(alpha: 0.3),
            ),
            const SizedBox(height: _Spacing.md),
            Text(
              l10n.noRecords,
              style: TextStyle(
                fontSize: _FontSize.body,
                color: _Colors.textHint.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<DateTime, List<Record>> _groupRecordsByDate(List<Record> records) {
    final grouped = <DateTime, List<Record>>{};
    for (var record in records) {
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
    return grouped;
  }

  List<DateTime> _getDatesWithRecords(Map<DateTime, List<Record>> grouped) {
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // 降序排列
    return dates;
  }

  List<DateTime> _getTodayOnly() {
    final now = DateTime.now();
    return [DateTime(now.year, now.month, now.day)];
  }

  String _formatDateTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final l10n = AppLocalizations.of(context)!;

    if (date == today) {
      return l10n.today;
    } else if (date == yesterday) {
      return l10n.yesterday;
    } else {
      return DateFormat('M/d').format(date);
    }
  }

  String _getDateLabel(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.getWeekday(date.weekday);
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  /// 统一清洗标签：
  /// - 去掉空白项
  /// - 将 "懊恼，沮丧，焦虑" 这类合并字符串拆成多个标签
  /// - 去重并保持原顺序
  List<String> _normalizeMoodTags(List<String>? moods) {
    if (moods == null || moods.isEmpty) return const [];

    final tags = <String>[];
    final seen = <String>{};
    final splitPattern = RegExp(r'[，,、；;|/\\\n]+');

    for (final item in moods) {
      for (final token in item.split(splitPattern)) {
        final tag = token.trim();
        if (tag.isEmpty) continue;
        if (seen.add(tag)) {
          tags.add(tag);
        }
      }
    }

    return tags;
  }
}
