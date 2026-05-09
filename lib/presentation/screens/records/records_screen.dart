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
import '../../../core/network/ocean_api_client.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/ocean_account_service.dart';
import '../../../core/services/daily_summary_service.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_state.dart';
import '../../bloc/record/record_event.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../../widgets/daily_mood_picker.dart';
import '../record_detail/record_detail_screen.dart';

const emptyRecordsGuidanceItems = [
  '可以用语音或文字记下一段想法、情绪、梦境或片刻观察。',
  '记录变多后，这里会按日期整理出时间线和每日心情概览。',
  '未登录时数据保存在本机；登录后会自动迁移并备份到服务端。',
];

class RecordsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  final HiveDatabase? database;
  final DailySummaryService? dailySummaryService;

  const RecordsScreen({
    super.key,
    this.onNavigateToHome,
    this.database,
    this.dailySummaryService,
  });

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late final HiveDatabase _database;
  late final DailySummaryService _dailySummaryService;
  OceanUserDataApi? _userDataApi;
  final Map<String, String> _dailyMoods = {};
  final Map<String, DailySummary> _dailySummaries = {};
  final Set<String> _generatingSummaries = {};
  bool _isRefreshingDailySummary = false;
  StreamSubscription<DailySummaryUpdate>? _dailySummarySubscription;
  StreamSubscription<void>? _accountDataSubscription;
  String? _lastDailySummarySyncSignature;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? getIt<HiveDatabase>();
    _dailySummaryService =
        widget.dailySummaryService ?? getIt<DailySummaryService>();
    _userDataApi =
        getIt.isRegistered<OceanApiClient>() ? getIt<OceanApiClient>() : null;
    _dailySummarySubscription = _dailySummaryService.summaryUpdates.listen((
      update,
    ) {
      if (!mounted) return;
      setState(() {
        _dailySummaries[update.key] = update.summary;
        _generatingSummaries.remove(update.key);
      });
    });
    if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
      _accountDataSubscription =
          getIt<OceanAccountDataRefreshService>().changes.listen((_) {
        if (!mounted) return;
        _reloadAccountScopedData();
      });
    }
    _loadRecords();
    _loadDailyMoods();
  }

  @override
  void dispose() {
    _dailySummarySubscription?.cancel();
    _accountDataSubscription?.cancel();
    super.dispose();
  }

  void _loadRecords() {
    context.read<RecordBloc>().add(const RecordLoadList());
  }

  void _loadDailyMoods() {
    _dailyMoods.clear();
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

  void _reloadAccountScopedData() {
    _dailySummaries.clear();
    _generatingSummaries.clear();
    _lastDailySummarySyncSignature = null;
    _loadDailyMoods();
    _loadRecords();
  }

  /// 加载日总结并在需要时触发生成
  void _loadDailySummaries(Map<DateTime, List<Record>> groupedRecords) {
    var shouldUpdateState = false;
    final pendingGenerations = <MapEntry<DateTime, List<Record>>>[];
    final activeSummaryKeys = <String>{};

    for (final entry in groupedRecords.entries) {
      final date = entry.key;
      final records = entry.value;
      final summaryKey = getDailySummaryKey(date);
      activeSummaryKeys.add(summaryKey);

      // 加载已缓存的日总结
      final existingSummary = _dailySummaryService.getDailySummary(date);
      if (existingSummary != null &&
          _dailySummaries[summaryKey] != existingSummary) {
        _dailySummaries[summaryKey] = existingSummary;
        shouldUpdateState = true;
      }

      // 检查是否需要生成/重新生成
      if (_dailySummaryService.needsRegeneration(date, records.length) &&
          !_generatingSummaries.contains(summaryKey)) {
        _generatingSummaries.add(summaryKey);
        pendingGenerations.add(MapEntry(date, records));
        shouldUpdateState = true;
      }
    }

    final staleSummaryKeys = _dailySummaries.keys
        .where((key) => !activeSummaryKeys.contains(key))
        .toList(growable: false);
    if (staleSummaryKeys.isNotEmpty) {
      for (final key in staleSummaryKeys) {
        _dailySummaries.remove(key);
      }
      shouldUpdateState = true;
    }

    final staleGeneratingKeys = _generatingSummaries
        .where((key) => !activeSummaryKeys.contains(key))
        .toList(growable: false);
    if (staleGeneratingKeys.isNotEmpty) {
      _generatingSummaries.removeAll(staleGeneratingKeys);
      shouldUpdateState = true;
    }

    if (shouldUpdateState && mounted) {
      setState(() {});
    }

    for (final pending in pendingGenerations) {
      _generateDailySummary(pending.key, pending.value, alreadyMarked: true);
    }
  }

  void _syncDailySummariesIfNeeded(List<Record> records) {
    final groupedRecords = _groupRecordsByDate(records);
    final nextSignature = buildDailySummarySyncSignature(groupedRecords);
    if (_lastDailySummarySyncSignature == nextSignature) {
      return;
    }
    _lastDailySummarySyncSignature = nextSignature;
    _loadDailySummaries(groupedRecords);
  }

  bool _isListLoadError(RecordState state) {
    final message = state.errorMessage;
    return state.hasError && message != null && message.startsWith('加载记录失败');
  }

  /// 异步生成日总结
  void _generateDailySummary(
    DateTime date,
    List<Record> records, {
    bool alreadyMarked = false,
  }) {
    final summaryKey = getDailySummaryKey(date);
    if (!alreadyMarked) {
      if (mounted) {
        setState(() {
          _generatingSummaries.add(summaryKey);
        });
      } else {
        _generatingSummaries.add(summaryKey);
      }
    }

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
      final dateKey = key.substring('daily_mood_'.length);
      final clientUpdatedAt = DateTime.now().toUtc().toIso8601String();
      final api = _userDataApi;
      if (api != null && await api.isSignedIn) {
        await api.updateDailyMood(dateKey, {
          'imagePath': selectedMood.imagePath,
          'clientUpdatedAt': clientUpdatedAt,
        });
      }
      await _database.settingsBox.put(key, selectedMood.imagePath);
      await _database.settingsBox.put(
        'ocean_sync_updated_at_daily_mood_$dateKey',
        clientUpdatedAt,
      );
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

      if (result?.action == NVCModalAction.confirm &&
          result?.analysis != null) {
        final updatedRecord = record.copyWith(
          nvc: result!.analysis,
          processingMode: ProcessingMode.withNVC,
          moods: result.analysis!.feelings.map((f) => f.feeling).toList(),
          needs: result.analysis!.needs.map((n) => n.need).toList(),
          createdAt: result.selectedDateTime ?? record.createdAt,
          updatedAt: DateTime.now(),
        );
        context.read<RecordBloc>().add(RecordUpdate(record: updatedRecord));
      } else if (result?.action == NVCModalAction.delete) {
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
                    child: BlocConsumer<RecordBloc, RecordState>(
                      listenWhen: (previous, current) =>
                          previous.records != current.records ||
                          previous.status != current.status,
                      listener: (context, state) {
                        if (state.isLoading || _isListLoadError(state)) {
                          return;
                        }
                        _syncDailySummariesIfNeeded(state.records);
                      },
                      builder: (context, state) {
                        if (state.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accent),
                            ),
                          );
                        }

                        if (_isListLoadError(state)) {
                          return _buildErrorState(state.errorMessage);
                        }

                        final groupedRecords =
                            _groupRecordsByDate(state.records);
                        final dateRange = state.isEmpty
                            ? _getTodayOnly()
                            : _getDatesWithRecords(groupedRecords);

                        return RefreshIndicator(
                          onRefresh: () async => _loadRecords(),
                          color: AppColors.accent,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.sm,
                              AppSpacing.xl,
                              AppSpacing.xxl,
                            ),
                            itemCount: dateRange.length,
                            itemBuilder: (context, index) {
                              final date = dateRange[index];
                              final records = groupedRecords[date] ?? [];
                              return _buildDaySection(
                                date,
                                records,
                                isFirst: index == 0,
                              );
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
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.dailyRecords,
            style: AppTypography.pageTitle.copyWith(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isRefreshingDailySummary
                  ? null
                  : _forceRefreshLatestDailySummary,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              splashColor: AppColors.accent.withValues(alpha: 0.18),
              highlightColor: AppColors.accent.withValues(alpha: 0.10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
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
                              AppColors.accent.withValues(alpha: 0.85),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppColors.accent,
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
              borderRadius: BorderRadius.circular(AppSpacing.xl),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 28,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            errorMessage ?? l10n.loadFailed,
            textAlign: TextAlign.center,
            style: AppTypography.bodySecondary.copyWith(
              fontSize: 15,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loadRecords,
              borderRadius: BorderRadius.circular(AppSpacing.xxl),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSpacing.xxl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  l10n.retry,
                  style: AppTypography.actionLabel.copyWith(
                    color: Colors.white,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建每天的记录区块
  Widget _buildDaySection(
    DateTime date,
    List<Record> records, {
    required bool isFirst,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: isFirst ? AppSpacing.xl : AppSpacing.md),

        // 日期标题行
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 日期指示条
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _formatDateTitle(date),
              style: AppTypography.sectionTitle.copyWith(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _getDateLabel(date),
              style: AppTypography.timeLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

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
    final displayMoodLabel = localizedMoodLabel(context, displayMood);
    final aiMoodWord = dailySummary?.moodWord.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCardSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 心情图标（可点击）
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleMoodTap(date),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
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
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: () => _handleMoodTap(date),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayMoodLabel,
                            style: AppTypography.sectionTitle.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          // AI 返回的情绪关键词标签（放在“心情”右侧）
                          if (dailySummary != null &&
                              aiMoodWord.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                aiMoodWord,
                                style: AppTypography.chipLabel.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                          // 正在生成中指示
                          if (isGenerating) ...[
                            const SizedBox(width: AppSpacing.xs),
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accent.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (dailySummary != null &&
                          dailySummary.oneSentence.isNotEmpty)
                        Text(
                          dailySummary.oneSentence,
                          style: AppTypography.sectionSubtle.copyWith(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          l10n.recordsCount(records.length),
                          style: AppTypography.sectionSubtle.copyWith(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
                  style: AppTypography.timeLabel.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // 圆点
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                // 连接线
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      color: AppColors.divider,
                    ),
                  )
                else
                  const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // 右侧卡片
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleRecordTap(record),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: isLast ? AppSpacing.sm : AppSpacing.lg,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppSpacing.lg),
                    border: Border.all(color: AppColors.border, width: 0.5),
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
                      if (record.transcription.isNotEmpty)
                        Text(
                          record.transcription,
                          style: const TextStyle(
                            fontSize: 15.0,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (hasMoods) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: moodTags.map((mood) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgPrimary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                mood,
                                style: AppTypography.chipLabel.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xxl),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.9),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 28,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.noRecords,
                      style: AppTypography.sectionTitle.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '先留下一点点痕迹，Ocean 会慢慢帮你看见情绪和需要的线索。',
                      style: AppTypography.bodySecondary.copyWith(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...emptyRecordsGuidanceItems.map(_buildEmptyGuidanceRow),
          const SizedBox(height: 18),
          if (widget.onNavigateToHome != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onNavigateToHome,
                icon: const Icon(Icons.radio_button_checked_rounded, size: 18),
                label: const Text('去记录此刻'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: AppTypography.actionLabel.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyGuidanceRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppColors.bgCardSecondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySecondary.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
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
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
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

@visibleForTesting
String buildDailySummarySyncSignature(
    Map<DateTime, List<Record>> groupedRecords) {
  if (groupedRecords.isEmpty) {
    return 'empty';
  }

  final sortedDates = groupedRecords.keys.toList()
    ..sort((a, b) => b.compareTo(a));
  return sortedDates.map((date) {
    final records = [...(groupedRecords[date] ?? const <Record>[])];
    records.sort((a, b) => a.id.compareTo(b.id));
    final recordSignature = records
        .map((record) =>
            '${record.id}:${record.createdAt.millisecondsSinceEpoch}:${record.updatedAt.millisecondsSinceEpoch}')
        .join(',');
    return '${date.year}-${date.month}-${date.day}|$recordSignature';
  }).join(';');
}
