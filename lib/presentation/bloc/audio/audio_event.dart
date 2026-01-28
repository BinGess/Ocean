// 音频事件定义
// 定义所有与音频录制相关的事件

import 'package:equatable/equatable.dart';

abstract class AudioEvent extends Equatable {
  const AudioEvent();

  @override
  List<Object?> get props => [];
}

/// 开始录音事件
class AudioStartRecording extends AudioEvent {
  const AudioStartRecording();
}

/// 停止录音事件
class AudioStopRecording extends AudioEvent {
  const AudioStopRecording();
}

/// 暂停录音事件
class AudioPauseRecording extends AudioEvent {
  const AudioPauseRecording();
}

/// 恢复录音事件
class AudioResumeRecording extends AudioEvent {
  const AudioResumeRecording();
}

/// 取消录音事件
class AudioCancelRecording extends AudioEvent {
  const AudioCancelRecording();
}

/// 更新录音时长事件
class AudioUpdateDuration extends AudioEvent {
  final double duration;

  const AudioUpdateDuration(this.duration);

  @override
  List<Object?> get props => [duration];
}

/// 权限检查事件
class AudioCheckPermission extends AudioEvent {
  const AudioCheckPermission();
}

/// 权限请求事件
class AudioRequestPermission extends AudioEvent {
  const AudioRequestPermission();
}
