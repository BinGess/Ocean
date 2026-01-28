import 'package:equatable/equatable.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/nvc_analysis.dart';

abstract class RecordEvent extends Equatable {
  const RecordEvent();

  @override
  List<Object?> get props => [];
}

/// 创建快速笔记
class RecordCreateQuickNote extends RecordEvent {
  final String audioPath;
  final ProcessingMode mode;
  final List<String>? selectedMoods;
  final String? transcription;
  final NVCAnalysis? nvcAnalysis;

  const RecordCreateQuickNote({
    required this.audioPath,
    required this.mode,
    this.selectedMoods,
    this.transcription,
    this.nvcAnalysis,
  });

  @override
  List<Object?> get props => [audioPath, mode, selectedMoods, transcription, nvcAnalysis];
}

/// 分析 NVC
class RecordAnalyzeNVC extends RecordEvent {
  final String text;

  const RecordAnalyzeNVC(this.text);

  @override
  List<Object?> get props => [text];
}

/// 加载记录列表
class RecordLoadList extends RecordEvent {
  final RecordType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  const RecordLoadList({
    this.type,
    this.startDate,
    this.endDate,
    this.limit,
  });

  @override
  List<Object?> get props => [type, startDate, endDate, limit];
}

/// 更新记录
class RecordUpdate extends RecordEvent {
  final Record record;

  const RecordUpdate({required this.record});

  @override
  List<Object?> get props => [record];
}

/// 删除记录
class RecordDelete extends RecordEvent {
  final String id;

  const RecordDelete({required this.id});

  @override
  List<Object?> get props => [id];
}

/// 选择记录
class RecordSelect extends RecordEvent {
  final Record record;

  const RecordSelect({required this.record});

  @override
  List<Object?> get props => [record];
}

/// 清除选择
class RecordClearSelection extends RecordEvent {
  const RecordClearSelection();
}

/// 改变处理模式
class RecordChangeProcessingMode extends RecordEvent {
  final String recordId;
  final ProcessingMode newMode;

  const RecordChangeProcessingMode({
    required this.recordId,
    required this.newMode,
  });

  @override
  List<Object?> get props => [recordId, newMode];
}

/// 转写音频
class RecordTranscribe extends RecordEvent {
  final String audioPath;

  const RecordTranscribe(this.audioPath);

  @override
  List<Object?> get props => [audioPath];
}
