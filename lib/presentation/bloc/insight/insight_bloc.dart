// 洞察 BLoC
// 管理周数据分析的加载与刷新。
// 周报内容（InsightReport）由服务端 cron 任务每周日 20:00 CST 自动生成，
// 客户端不再主动调用任何本地 AI 生成接口。

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/weekly_analysis.dart';
import '../../../domain/usecases/get_weekly_insights_usecase.dart';
import '../../../domain/usecases/build_weekly_analysis_usecase.dart';
import '../../../domain/usecases/generate_insight_report_usecase.dart'
    show GenerateInsightReportParams;
import '../../../domain/repositories/insight_repository.dart';
import 'insight_event.dart';
import 'insight_state.dart';

class InsightBloc extends Bloc<InsightEvent, InsightState> {
  final GetWeeklyInsightsUseCase getWeeklyInsightsUseCase;
  final BuildWeeklyAnalysisUseCase buildWeeklyAnalysisUseCase;
  final InsightRepository insightRepository;

  InsightBloc({
    required this.getWeeklyInsightsUseCase,
    required this.buildWeeklyAnalysisUseCase,
    required this.insightRepository,
  }) : super(InsightState.initial()) {
    on<InsightGenerateCurrentWeek>(_onGenerateCurrentWeek);
    on<InsightLoadCurrentWeek>(_onLoadCurrentWeek);
    on<InsightAccountDataChanged>(_onAccountDataChanged);
    on<InsightLoadList>(_onLoadList);
    on<InsightUpdatePatternFeedback>(_onUpdatePatternFeedback);
    on<InsightUpdateExperimentStatus>(_onUpdateExperimentStatus);
    on<InsightUpdateExperimentFeedback>(_onUpdateExperimentFeedback);
  }

  /// 获取当前周的周范围字符串
  String _getCurrentWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final startStr =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final endStr =
        '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';

    return '$startStr ~ $endStr';
  }

  /// 加载当前周洞察（优先使用缓存）
  Future<void> _onLoadCurrentWeek(
    InsightLoadCurrentWeek event,
    Emitter<InsightState> emit,
  ) async {
    final currentWeekRange = _getCurrentWeekRange();
    final analysis = await _buildAnalysisForCurrentWeek(currentWeekRange);

    // 内存缓存有效时直接使用
    if (state.isCacheValid(currentWeekRange)) {
      debugPrint('📦 InsightBloc: 使用内存缓存 (${state.lastFetchTime})');
      if (state.status != InsightStatus.success) {
        emit(state.copyWith(
          status: InsightStatus.success,
          weeklyAnalysis: analysis,
        ));
      }
      return;
    }

    // 读取本地持久化缓存（同周有效，不重复网络请求）
    try {
      final cached =
          await insightRepository.getCachedInsightReport(currentWeekRange);
      if (cached != null) {
        debugPrint('💾 InsightBloc: 使用本地缓存 (${cached.cachedAt})');
        emit(state.copyWith(
          status: InsightStatus.success,
          currentReport: cached.report,
          weeklyAnalysis: analysis,
          lastFetchTime: cached.cachedAt,
          currentWeekRange: currentWeekRange,
          progressMessage: null,
        ));
        return;
      }
    } catch (_) {
      // 缓存读取失败不影响主流程
    }

    // 无本地缓存：展示可用的数据分析，报告内容留空等服务端生成
    debugPrint('ℹ️ InsightBloc: 无本周报告缓存，展示数据分析');
    emit(state.copyWith(
      status: InsightStatus.success,
      weeklyAnalysis: analysis,
      clearReport: true,
      currentWeekRange: currentWeekRange,
      progressMessage: null,
    ));
  }

  Future<void> _onAccountDataChanged(
    InsightAccountDataChanged event,
    Emitter<InsightState> emit,
  ) async {
    emit(InsightState.initial());
    add(const InsightLoadCurrentWeek());
  }

  /// 强制刷新当前周的数据分析（下拉刷新触发）
  /// 注：不再调用本地 AI；服务端已通过 cron 任务接管报告生成。
  Future<void> _onGenerateCurrentWeek(
    InsightGenerateCurrentWeek event,
    Emitter<InsightState> emit,
  ) async {
    final currentWeekRange = _getCurrentWeekRange();

    emit(state.copyWith(
      status: InsightStatus.generating,
      progressMessage: '正在刷新数据...',
    ));

    final analysis = await _buildAnalysisForCurrentWeek(currentWeekRange);

    emit(state.copyWith(
      status: InsightStatus.success,
      weeklyAnalysis: analysis,
      currentWeekRange: currentWeekRange,
      lastFetchTime: DateTime.now(),
      progressMessage: null,
    ));
  }

  Future<WeeklyAnalysis?> _buildAnalysisForCurrentWeek(String weekRange) async {
    final params = GenerateInsightReportParams.forCurrentWeek();

    // 优先从服务端获取（更准确的统计）
    try {
      final startDate = _formatDate(params.startDate);
      final endDate = _formatDate(params.endDate);
      final serverAnalysis = await insightRepository.fetchServerWeeklyAnalysis(
        startDate: startDate,
        endDate: endDate,
      );
      if (serverAnalysis != null) {
        debugPrint('✅ InsightBloc: 使用服务端周分析数据');
        return serverAnalysis;
      }
    } catch (e) {
      debugPrint('⚠️ InsightBloc: 服务端分析失败，降级到本地计算: $e');
    }

    // 降级：本地计算（离线 / 未登录 / 服务端异常）
    try {
      return await buildWeeklyAnalysisUseCase(
        BuildWeeklyAnalysisParams(
          weekRange: weekRange,
          startDate: params.startDate,
          endDate: params.endDate,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 加载洞察列表（历史记录）
  Future<void> _onLoadList(
    InsightLoadList event,
    Emitter<InsightState> emit,
  ) async {
    emit(state.copyWith(status: InsightStatus.loading));

    try {
      final insights = await getWeeklyInsightsUseCase(
        GetWeeklyInsightsParams(limit: event.limit),
      );

      emit(state.copyWith(
        status: InsightStatus.success,
        insights: insights,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: '加载洞察失败: $e',
      ));
    }
  }

  Future<void> _onUpdatePatternFeedback(
    InsightUpdatePatternFeedback event,
    Emitter<InsightState> emit,
  ) async {
    try {
      await insightRepository.updatePatternFeedback(
        event.insightId,
        event.patternId,
        event.feedback,
      );
      emit(state.copyWith(status: InsightStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: '更新反馈失败: $e',
      ));
    }
  }

  Future<void> _onUpdateExperimentStatus(
    InsightUpdateExperimentStatus event,
    Emitter<InsightState> emit,
  ) async {
    try {
      await insightRepository.updateExperimentStatus(
        event.insightId,
        event.experimentId,
        event.status,
      );
      emit(state.copyWith(status: InsightStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: '更新状态失败: $e',
      ));
    }
  }

  Future<void> _onUpdateExperimentFeedback(
    InsightUpdateExperimentFeedback event,
    Emitter<InsightState> emit,
  ) async {
    try {
      await insightRepository.updateExperimentFeedback(
        event.insightId,
        event.experimentId,
        event.feedback,
      );
      emit(state.copyWith(status: InsightStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: '更新反馈失败: $e',
      ));
    }
  }
}
