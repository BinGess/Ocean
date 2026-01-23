/// 音频状态定义
/// 定义所有与音频录制相关的状态

import 'package:equatable/equatable.dart';

/// 录音状态枚举
enum RecordingStatus {
  initial, // 初始状态
  permissionChecking, // 检查权限中
  permissionDenied, // 权限被拒绝
  ready, // 准备就绪
  recording, // 录音中
  paused, // 已暂停
  stopped, // 已停止
  processing, // 处理中
  completed, // 完成
  error, // 错误
}

/// 音频状态
class AudioState extends Equatable {
  final RecordingStatus status;
  final double duration; // 录音时长（秒）
  final String? audioPath; // 录音文件路径
  final String? errorMessage; // 错误信息
  final bool hasPermission; // 是否有录音权限

  const AudioState({
    required this.status,
    this.duration = 0.0,
    this.audioPath,
    this.errorMessage,
    this.hasPermission = false,
  });

  /// 初始状态
  factory AudioState.initial() {
    return const AudioState(
      status: RecordingStatus.initial,
      duration: 0.0,
      hasPermission: false,
    );
  }

  /// 复制并修改状态
  AudioState copyWith({
    RecordingStatus? status,
    double? duration,
    String? audioPath,
    String? errorMessage,
    bool? hasPermission,
  }) {
    return AudioState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
      errorMessage: errorMessage ?? this.errorMessage,
      hasPermission: hasPermission ?? this.hasPermission,
    );
  }

  /// 便捷 getter
  bool get isRecording => status == RecordingStatus.recording;
  bool get isPaused => status == RecordingStatus.paused;
  bool get isProcessing => status == RecordingStatus.processing;
  bool get hasError => status == RecordingStatus.error;
  bool get isCompleted => status == RecordingStatus.completed;
  bool get canRecord =>
      hasPermission &&
      status != RecordingStatus.recording &&
      status != RecordingStatus.processing;

  @override
  List<Object?> get props => [
        status,
        duration,
        audioPath,
        errorMessage,
        hasPermission,
      ];
}
