// 洞察事件定义

import 'package:equatable/equatable.dart';

abstract class InsightEvent extends Equatable {
  const InsightEvent();

  @override
  List<Object?> get props => [];
}

/// 生成当前周洞察（强制刷新，不检查缓存）
class InsightGenerateCurrentWeek extends InsightEvent {
  const InsightGenerateCurrentWeek();
}

/// 加载当前周洞察（优先使用缓存）
class InsightLoadCurrentWeek extends InsightEvent {
  const InsightLoadCurrentWeek();
}

/// 生成指定周洞察
class InsightGenerateForWeek extends InsightEvent {
  final String weekRange;
  final DateTime startDate;
  final DateTime endDate;

  const InsightGenerateForWeek({
    required this.weekRange,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [weekRange, startDate, endDate];
}

/// 加载洞察列表
class InsightLoadList extends InsightEvent {
  final int? limit;

  const InsightLoadList({this.limit});

  @override
  List<Object?> get props => [limit];
}

/// 更新模式反馈
class InsightUpdatePatternFeedback extends InsightEvent {
  final String insightId;
  final String patternId;
  final String feedback; // 'like' | 'dislike' | 'uncertain'

  const InsightUpdatePatternFeedback({
    required this.insightId,
    required this.patternId,
    required this.feedback,
  });

  @override
  List<Object?> get props => [insightId, patternId, feedback];
}

/// 更新微实验状态
class InsightUpdateExperimentStatus extends InsightEvent {
  final String insightId;
  final String experimentId;
  final String status; // 'pending' | 'in_progress' | 'completed'

  const InsightUpdateExperimentStatus({
    required this.insightId,
    required this.experimentId,
    required this.status,
  });

  @override
  List<Object?> get props => [insightId, experimentId, status];
}

/// 更新微实验反馈
class InsightUpdateExperimentFeedback extends InsightEvent {
  final String insightId;
  final String experimentId;
  final String feedback;

  const InsightUpdateExperimentFeedback({
    required this.insightId,
    required this.experimentId,
    required this.feedback,
  });

  @override
  List<Object?> get props => [insightId, experimentId, feedback];
}
