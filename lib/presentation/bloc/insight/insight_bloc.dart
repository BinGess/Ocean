// 洞察 BLoC
// 管理周洞察的生成、查询、反馈等操作

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/generate_weekly_insight_usecase.dart';
import '../../../domain/usecases/get_weekly_insights_usecase.dart';
import '../../../domain/repositories/insight_repository.dart';
import 'insight_event.dart';
import 'insight_state.dart';

class InsightBloc extends Bloc<InsightEvent, InsightState> {
  final GenerateWeeklyInsightUseCase generateWeeklyInsightUseCase;
  final GetWeeklyInsightsUseCase getWeeklyInsightsUseCase;
  final InsightRepository insightRepository;

  InsightBloc({
    required this.generateWeeklyInsightUseCase,
    required this.getWeeklyInsightsUseCase,
    required this.insightRepository,
  }) : super(InsightState.initial()) {
    // 注册事件处理器
    on<InsightGenerateCurrentWeek>(_onGenerateCurrentWeek);
    on<InsightGenerateForWeek>(_onGenerateForWeek);
    on<InsightLoadList>(_onLoadList);
    on<InsightUpdatePatternFeedback>(_onUpdatePatternFeedback);
    on<InsightUpdateExperimentStatus>(_onUpdateExperimentStatus);
    on<InsightUpdateExperimentFeedback>(_onUpdateExperimentFeedback);
  }

  /// 生成当前周洞察
  Future<void> _onGenerateCurrentWeek(
    InsightGenerateCurrentWeek event,
    Emitter<InsightState> emit,
  ) async {
    emit(state.copyWith(
      status: InsightStatus.generating,
      progressMessage: '正在分析本周记录...',
    ));

    try {
      final params = GenerateWeeklyInsightParams.forCurrentWeek();

      // 更新进度
      emit(state.copyWith(progressMessage: '正在生成情绪模式...'));

      final insight = await generateWeeklyInsightUseCase(params);

      // 将新洞察添加到列表开头
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
