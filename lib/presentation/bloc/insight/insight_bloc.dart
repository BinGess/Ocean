// 洞察 BLoC
// 管理周洞察的生成、查询、反馈等操作

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/generate_weekly_insight_usecase.dart';
import '../../../domain/usecases/generate_insight_report_usecase.dart';
import '../../../domain/usecases/get_weekly_insights_usecase.dart';
import '../../../domain/repositories/insight_repository.dart';
import '../../../core/services/ai_auth_service.dart';
import 'insight_event.dart';
import 'insight_state.dart';

class InsightBloc extends Bloc<InsightEvent, InsightState> {
  final GenerateWeeklyInsightUseCase generateWeeklyInsightUseCase;
  final GenerateInsightReportUseCase generateInsightReportUseCase;
  final GetWeeklyInsightsUseCase getWeeklyInsightsUseCase;
  final InsightRepository insightRepository;
  final AIAuthService aiAuthService;

  InsightBloc({
    required this.generateWeeklyInsightUseCase,
    required this.generateInsightReportUseCase,
    required this.getWeeklyInsightsUseCase,
    required this.insightRepository,
    required this.aiAuthService,
  }) : super(InsightState.initial()) {
    // 注册事件处理器
    on<InsightGenerateCurrentWeek>(_onGenerateCurrentWeek);
    on<InsightLoadCurrentWeek>(_onLoadCurrentWeek);
    on<InsightGenerateForWeek>(_onGenerateForWeek);
    on<InsightLoadList>(_onLoadList);
    on<InsightUpdatePatternFeedback>(_onUpdatePatternFeedback);
    on<InsightUpdateExperimentStatus>(_onUpdateExperimentStatus);
    on<InsightUpdateExperimentFeedback>(_onUpdateExperimentFeedback);
  }

  /// 获取当前周的周范围字符串
  String _getCurrentWeekRange() {
    final now = DateTime.now();
    // 计算本周一
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final startStr = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final endStr = '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';

    return '$startStr ~ $endStr';
  }

  /// 加载当前周洞察（优先使用缓存）
  Future<void> _onLoadCurrentWeek(
    InsightLoadCurrentWeek event,
    Emitter<InsightState> emit,
  ) async {
    final currentWeekRange = _getCurrentWeekRange();

    // 检查缓存是否有效
    if (state.isCacheValid(currentWeekRange)) {
      debugPrint('📦 InsightBloc: 使用缓存的洞察报告 (${state.lastFetchTime})');
      // 缓存有效，直接返回成功状态（保持现有数据）
      if (state.status != InsightStatus.success) {
        emit(state.copyWith(status: InsightStatus.success));
      }
      return;
    }

    // 检查本地持久化缓存（同一周的缓存整周有效，同一次安装内不重复请求）
    try {
      final cached = await insightRepository.getCachedInsightReport(currentWeekRange);
      if (cached != null) {
        debugPrint('💾 InsightBloc: 使用本地缓存洞察报告 (${cached.cachedAt}, 本周有效)');
        emit(state.copyWith(
          status: InsightStatus.success,
          currentReport: cached.report,
          lastFetchTime: cached.cachedAt,
          currentWeekRange: currentWeekRange,
          progressMessage: null,
        ));
        return;
      }
    } catch (_) {
      // 缓存读取失败不影响主流程
    }

    // 检查AI授权状态 - 未授权时显示友好引导（不自动弹窗）
    final isAuthorized = await aiAuthService.isAuthorized;
    if (!isAuthorized) {
      debugPrint('InsightBloc: 无缓存且未授权AI，显示授权引导');
      emit(state.copyWith(
        status: InsightStatus.needsAIAuth,
        clearReport: true,
      ));
      return; // 显示引导页面，等待用户手动操作
    }

    debugPrint('🔄 InsightBloc: 无本地缓存，重新生成洞察');
    // 缓存无效，触发生成
    add(const InsightGenerateCurrentWeek());
  }

  /// 生成当前周洞察（使用新的洞察报告 API，强制刷新）
  Future<void> _onGenerateCurrentWeek(
    InsightGenerateCurrentWeek event,
    Emitter<InsightState> emit,
  ) async {
    // 1. 检查AI授权状态
    final isAuthorized = await aiAuthService.isAuthorized;
    if (!isAuthorized) {
      debugPrint('InsightBloc: 需要AI授权');
      emit(state.copyWith(
        status: InsightStatus.needsAIAuth,
        clearReport: true,
      ));
      return; // 显示引导页面，等待用户授权
    }

    // 2. 已授权，继续生成逻辑
    final currentWeekRange = _getCurrentWeekRange();

    emit(state.copyWith(
      status: InsightStatus.generating,
      progressMessage: '正在分析本周记录...',
      clearReport: true,
    ));

    try {
      final params = GenerateInsightReportParams.forCurrentWeek();

      // 更新进度
      emit(state.copyWith(
        status: InsightStatus.generating,
        progressMessage: '正在生成洞察报告...',
      ));

      debugPrint('🔮 InsightBloc: 开始生成洞察报告');
      final report = await generateInsightReportUseCase(params);
      debugPrint('✅ InsightBloc: 洞察报告生成成功');

      // 持久化缓存
      try {
        await insightRepository.saveInsightReportCache(report);
      } catch (_) {
        // 缓存写入失败不影响主流程
      }

      emit(state.copyWith(
        status: InsightStatus.success,
        currentReport: report,
        lastFetchTime: DateTime.now(),
        currentWeekRange: currentWeekRange,
        progressMessage: null,
      ));
    } catch (e) {
      debugPrint('❌ InsightBloc: 洞察生成失败: $e');
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: e.toString(),
        progressMessage: null,
      ));
    }
  }

  /// 生成指定周洞察
  Future<void> _onGenerateForWeek(
    InsightGenerateForWeek event,
    Emitter<InsightState> emit,
  ) async {
    emit(state.copyWith(
      status: InsightStatus.generating,
      progressMessage: '正在分析记录...',
    ));

    try {
      final params = GenerateWeeklyInsightParams(
        weekRange: event.weekRange,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      final insight = await generateWeeklyInsightUseCase(params);

      // 将新洞察添加到列表
      final updatedInsights = [insight, ...state.insights];

      emit(state.copyWith(
        status: InsightStatus.success,
        insights: updatedInsights,
        currentInsight: insight,
        progressMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: e.toString(),
        progressMessage: null,
      ));
    }
  }

  /// 加载洞察列表
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

  /// 更新模式反馈
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

      // TODO: 更新本地状态中的洞察
      emit(state.copyWith(status: InsightStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: InsightStatus.error,
        errorMessage: '更新反馈失败: $e',
      ));
    }
  }

  /// 更新微实验状态
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

  /// 更新微实验反馈
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
