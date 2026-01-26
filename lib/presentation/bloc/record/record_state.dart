/// 记录状态定义

import 'package:equatable/equatable.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/nvc_analysis.dart';

/// 记录状态枚举
enum RecordStatus {
  initial, // 初始状态
  loading, // 加载中
  creating, // 创建中
  transcribing, // 转写中
  analyzing, // 分析中
  analyzed, // 分析完成（等待确认）
  success, // 成功
  error, // 错误
}

class RecordState extends Equatable {
  /// 状态
  final RecordStatus status;

  /// 记录列表
  final List<Record> records;

  /// 当前选中的记录
  final Record? selectedRecord;

  /// 最新创建的记录
  final Record? latestRecord;

  /// 错误信息
  final String? errorMessage;

  /// 是否有更多数据
  final bool hasMore;

  /// 当前正在转写的文本
  final String? transcription;

  /// NVC 分析结果
  final NVCAnalysis? nvcAnalysis;

  const RecordState({
    required this.status,
    required this.records,
    this.selectedRecord,
    this.latestRecord,
    this.errorMessage,
    this.hasMore = true,
    this.transcription,
    this.nvcAnalysis,
  });

  /// 初始状态
  factory RecordState.initial() {
    return const RecordState(
      status: RecordStatus.initial,
      records: [],
      selectedRecord: null,
      latestRecord: null,
      errorMessage: null,
      hasMore: true,
      transcription: null,
      nvcAnalysis: null,
    );
  }

  /// 复制并修改状态
  RecordState copyWith({
    RecordStatus? status,
    List<Record>? records,
    Record? selectedRecord,
    Record? latestRecord,
    String? errorMessage,
    bool? hasMore,
    bool clearSelection = false,
    bool clearLatest = false,
    bool clearNVCAnalysis = false,
    String? transcription,
    NVCAnalysis? nvcAnalysis,
  }) {
    return RecordState(
      status: status ?? this.status,
      records: records ?? this.records,
      selectedRecord:
          clearSelection ? null : (selectedRecord ?? this.selectedRecord),
      latestRecord: clearLatest ? null : (latestRecord ?? this.latestRecord),
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      transcription: transcription ?? this.transcription,
      nvcAnalysis: clearNVCAnalysis ? null : (nvcAnalysis ?? this.nvcAnalysis),
    );
  }

  /// 便捷的状态检查
  bool get isLoading => status == RecordStatus.loading;
  bool get isCreating => status == RecordStatus.creating;
  bool get isTranscribing => status == RecordStatus.transcribing;
  bool get isAnalyzing => status == RecordStatus.analyzing;
  bool get isAnalyzed => status == RecordStatus.analyzed;
  bool get isSuccess => status == RecordStatus.success;
  bool get hasError => status == RecordStatus.error;
  bool get isEmpty => records.isEmpty;

  @override
  List<Object?> get props => [
        status,
        records,
        selectedRecord,
        latestRecord,
        errorMessage,
        hasMore,
        transcription,
        nvcAnalysis,
      ];
}
