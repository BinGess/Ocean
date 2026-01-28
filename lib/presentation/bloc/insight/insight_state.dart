// 洞察状态定义

import 'package:equatable/equatable.dart';
import '../../../domain/entities/weekly_insight.dart';

/// 洞察状态枚举
enum InsightStatus {
  initial, // 初始状态
  loading, // 加载中
  generating, // 生成中
  success, // 成功
  error, // 错误
}

class InsightState extends Equatable {
  /// 状态
  final InsightStatus status;

  /// 洞察列表
  final List<WeeklyInsight> insights;

  /// 当前洞察
  final WeeklyInsight? currentInsight;

  /// 错误信息
  final String? errorMessage;

  /// 生成进度信息
  final String? progressMessage;

  const InsightState({
    required this.status,
    required this.insights,
    this.currentInsight,
    this.errorMessage,
    this.progressMessage,
  });

  /// 初始状态
  factory InsightState.initial() {
    return const InsightState(
      status: InsightStatus.initial,
      insights: [],
      currentInsight: null,
      errorMessage: null,
      progressMessage: null,
    );
  }

  /// 复制并修改状态
  InsightState copyWith({
    InsightStatus? status,
    List<WeeklyInsight>? insights,
    WeeklyInsight? currentInsight,
    String? errorMessage,
    String? progressMessage,
    bool clearCurrent = false,
  }) {
    return InsightState(
      status: status ?? this.status,
      insights: insights ?? this.insights,
      currentInsight:
          clearCurrent ? null : (currentInsight ?? this.currentInsight),
      errorMessage: errorMessage,
      progressMessage: progressMessage,
    );
  }

  /// 便捷的状态检查
  bool get isLoading => status == InsightStatus.loading;
  bool get isGenerating => status == InsightStatus.generating;
  bool get isSuccess => status == InsightStatus.success;
  bool get hasError => status == InsightStatus.error;
  bool get isEmpty => insights.isEmpty;

  @override
  List<Object?> get props => [
        status,
        insights,
        currentInsight,
        errorMessage,
        progressMessage,
      ];
}
