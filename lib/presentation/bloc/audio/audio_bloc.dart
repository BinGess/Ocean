/// 音频 BLoC
/// 处理音频录制相关的业务逻辑

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/audio_repository.dart';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final AudioRepository audioRepository;
  Timer? _durationTimer;

  AudioBloc({
    required this.audioRepository,
  }) : super(AudioState.initial()) {
    // 注册事件处理器
    on<AudioCheckPermission>(_onCheckPermission);
    on<AudioRequestPermission>(_onRequestPermission);
    on<AudioStartRecording>(_onStartRecording);
    on<AudioStopRecording>(_onStopRecording);
    on<AudioPauseRecording>(_onPauseRecording);
    on<AudioResumeRecording>(_onResumeRecording);
    on<AudioCancelRecording>(_onCancelRecording);
    on<AudioUpdateDuration>(_onUpdateDuration);
  }

  /// 检查权限
  Future<void> _onCheckPermission(
    AudioCheckPermission event,
    Emitter<AudioState> emit,
  ) async {
    emit(state.copyWith(status: RecordingStatus.permissionChecking));

    try {
      final hasPermission = await audioRepository.checkPermission();
      emit(state.copyWith(
        hasPermission: hasPermission,
        status: hasPermission
            ? RecordingStatus.ready
            : RecordingStatus.permissionDenied,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '权限检查失败: $e',
      ));
    }
  }

  /// 请求权限
  Future<void> _onRequestPermission(
    AudioRequestPermission event,
    Emitter<AudioState> emit,
  ) async {
    try {
      final granted = await audioRepository.requestPermission();
      emit(state.copyWith(
        hasPermission: granted,
        status: granted
            ? RecordingStatus.ready
            : RecordingStatus.permissionDenied,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '权限请求失败: $e',
      ));
    }
  }

  /// 开始录音
  Future<void> _onStartRecording(
    AudioStartRecording event,
    Emitter<AudioState> emit,
  ) async {
    print('AudioBloc: _onStartRecording called');
    if (!state.hasPermission) {
      print('AudioBloc: No permission');
      emit(state.copyWith(
        status: RecordingStatus.permissionDenied,
        errorMessage: '没有录音权限',
      ));
      return;
    }

    try {
      final success = await audioRepository.startRecording();
      print('AudioBloc: startRecording success: $success');

      if (success) {
        emit(state.copyWith(
          status: RecordingStatus.recording,
          duration: 0.0,
          audioPath: null,
          errorMessage: null,
        ));

        // 启动时长计时器
        _startDurationTimer();
      } else {
        emit(state.copyWith(
          status: RecordingStatus.error,
          errorMessage: '录音启动失败',
        ));
      }
    } catch (e) {
      print('AudioBloc: startRecording error: $e');
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '录音失败: $e',
      ));
    }
  }

  /// 停止录音
  Future<void> _onStopRecording(
    AudioStopRecording event,
    Emitter<AudioState> emit,
  ) async {
    print('AudioBloc: _onStopRecording called');
    _stopDurationTimer();

    emit(state.copyWith(status: RecordingStatus.processing));

    try {
      final audioPath = await audioRepository.stopRecording();
      print('AudioBloc: stopRecording path: $audioPath');

      if (audioPath != null) {
        emit(state.copyWith(
          status: RecordingStatus.completed,
          audioPath: audioPath,
        ));
      } else {
        emit(state.copyWith(
          status: RecordingStatus.error,
          errorMessage: '录音保存失败',
        ));
      }
    } catch (e) {
      print('AudioBloc: stopRecording error: $e');
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '停止录音失败: $e',
      ));
    }
  }

  /// 暂停录音
  Future<void> _onPauseRecording(
    AudioPauseRecording event,
    Emitter<AudioState> emit,
  ) async {
    _stopDurationTimer();

    try {
      await audioRepository.pauseRecording();
      emit(state.copyWith(status: RecordingStatus.paused));
    } catch (e) {
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '暂停录音失败: $e',
      ));
    }
  }

  /// 恢复录音
  Future<void> _onResumeRecording(
    AudioResumeRecording event,
    Emitter<AudioState> emit,
  ) async {
    try {
      await audioRepository.resumeRecording();
      emit(state.copyWith(status: RecordingStatus.recording));
      _startDurationTimer();
    } catch (e) {
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '恢复录音失败: $e',
      ));
    }
  }

  /// 取消录音
  Future<void> _onCancelRecording(
    AudioCancelRecording event,
    Emitter<AudioState> emit,
  ) async {
    _stopDurationTimer();

    try {
      await audioRepository.cancelRecording();
      emit(state.copyWith(
        status: RecordingStatus.ready,
        duration: 0.0,
        audioPath: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '取消录音失败: $e',
      ));
    }
  }

  /// 更新时长
  void _onUpdateDuration(
    AudioUpdateDuration event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(duration: event.duration));
  }

  /// 启动时长计时器
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final currentDuration = audioRepository.getCurrentDuration();
        add(AudioUpdateDuration(currentDuration));
      },
    );
  }

  /// 停止时长计时器
  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  Future<void> close() {
    _stopDurationTimer();
    return super.close();
  }
}
