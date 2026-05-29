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

/// 开始流式录音事件（带实时转写）
class AudioStartStreamingRecording extends AudioEvent {
  const AudioStartStreamingRecording();
}

/// 更新实时转写文本事件
class AudioUpdateStreamTranscription extends AudioEvent {
  final String text;
  final bool isFinal;

  const AudioUpdateStreamTranscription(this.text, {this.isFinal = false});

  @override
  List<Object?> get props => [text, isFinal];
}

/// 流式错误事件
///
/// [sessionToken] 创建订阅时捕获的录音会话标识（`_sessionToken` 的值）。
/// `_onStreamError` 用 `identical()` 与当前 `_sessionToken` 对比，
/// 若不匹配说明此错误来自上一次录音，直接忽略，防止污染新一轮录音。
class AudioStreamError extends AudioEvent {
  final String error;

  /// 产生此错误时所属的录音会话标识；null 表示无需会话校验（向后兼容）。
  final Object? sessionToken;

  // 构造器可为 const（默认 sessionToken=null 时完全 const 兼容）；
  // 传入运行时 Object() 的调用点不能加 const 关键字，但声明本身合法。
  const AudioStreamError(this.error, {this.sessionToken});

  @override
  List<Object?> get props => [error]; // sessionToken 不纳入相等性判断
}

/// 完成流式录音事件
class AudioFinalizeStreaming extends AudioEvent {
  const AudioFinalizeStreaming();
}

/// 预热事件（初始化权限/目录等，减少首录卡顿）
class AudioWarmUp extends AudioEvent {
  const AudioWarmUp();
}

/// 实时音量更新事件（0.0 ~ 1.0）
class AudioAmplitudeUpdated extends AudioEvent {
  final double amplitude;

  const AudioAmplitudeUpdated(this.amplitude);

  @override
  List<Object?> get props => [amplitude];
}
