// 音频 BLoC
// 处理音频录制相关的业务逻辑

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../core/network/doubao_asr_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final AudioRepository audioRepository;
  final DoubaoASRClient? asrClient; // 可选的ASR客户端
  Timer? _durationTimer;

  // 流式转写相关
  StreamSubscription<List<int>>? _audioStreamSubscription;
  StreamSubscription<ASRResponse>? _asrResponseSubscription;
  // 实时音量订阅
  StreamSubscription<double>? _amplitudeSubscription;

  // 防止重复触发的标志
  bool _isConnecting = false;
  // 连接期间取消标记
  bool _cancelRequested = false;
  // 最近一次是否被取消（防止误发完成事件）
  bool _wasCanceled = false;
  // 会话标识（取消后避免误发完成事件）
  Object? _sessionToken;

  AudioBloc({
    required this.audioRepository,
    this.asrClient,
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

    // 流式转写事件处理器
    on<AudioStartStreamingRecording>(_onStartStreamingRecording);
    on<AudioUpdateStreamTranscription>(_onUpdateStreamTranscription);
    on<AudioStreamError>(_onStreamError);
    on<AudioFinalizeStreaming>(_onFinalizeStreaming);
    on<AudioWarmUp>(_onWarmUp);
    on<AudioAmplitudeUpdated>(_onAmplitudeUpdated);
  }

  /// 外部请求取消（用于连接中提前终止）
  void requestCancel() {
    _cancelRequested = true;
    _wasCanceled = true;
    _sessionToken = null;
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
    debugPrint('AudioBloc: _onStartRecording called');
    _sessionToken = Object();
    _wasCanceled = false;
    if (!state.hasPermission) {
      debugPrint('AudioBloc: No permission');
      emit(state.copyWith(
        status: RecordingStatus.permissionDenied,
        errorMessage: '没有录音权限',
      ));
      return;
    }

    try {
      final success = await audioRepository.startRecording();
      debugPrint('AudioBloc: startRecording success: $success');

      if (success) {
        emit(state.copyWith(
          status: RecordingStatus.recording,
          duration: 0.0,
          audioPath: null,
          errorMessage: null,
          amplitude: 0.0,
        ));

        // 启动时长计时器
        _startDurationTimer();
        // 订阅实时音量
        _subscribeAmplitude();
      } else {
        emit(state.copyWith(
          status: RecordingStatus.error,
          errorMessage: '录音启动失败',
        ));
      }
    } catch (e) {
      debugPrint('AudioBloc: startRecording error: $e');
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
    debugPrint('AudioBloc: _onStopRecording called');
    _stopDurationTimer();
    _cancelAmplitudeSubscription();
    final session = _sessionToken;

    if (_wasCanceled || _cancelRequested) {
      emit(state.copyWith(
        status: RecordingStatus.ready,
        audioPath: null,
        clearTranscription: true,
      ));
      _wasCanceled = false;
      _cancelRequested = false;
      if (_sessionToken == session) {
        _sessionToken = null;
      }
      return;
    }

    emit(state.copyWith(status: RecordingStatus.processing));

    try {
      final audioPath = await audioRepository.stopRecording();
      debugPrint('AudioBloc: stopRecording path: $audioPath');

      if (audioPath != null) {
        if (_sessionToken != session || session == null) {
          return;
        }
        emit(state.copyWith(
          status: RecordingStatus.completed,
          audioPath: audioPath,
        ));
        _sessionToken = null;
      } else {
        emit(state.copyWith(
          status: RecordingStatus.error,
          errorMessage: '录音保存失败',
        ));
      }
    } catch (e) {
      debugPrint('AudioBloc: stopRecording error: $e');
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
    _cancelAmplitudeSubscription();
    final wasConnecting = _isConnecting;
    _cancelRequested = wasConnecting;
    _wasCanceled = true;
    _sessionToken = null;

    try {
      if (_isConnecting || state.isStreamingRecording) {
        await _cleanupStreamingResources();
        _isConnecting = false;
      }
      await audioRepository.cancelRecording();
      emit(state.copyWith(
        status: RecordingStatus.ready,
        duration: 0.0,
        audioPath: null,
        clearTranscription: true,
      ));
      _cancelRequested = false;
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
      const Duration(milliseconds: 250),
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

  /// 订阅麦克风实时音量
  void _subscribeAmplitude() {
    _amplitudeSubscription?.cancel();
    final stream = audioRepository.amplitudeStream;
    if (stream == null) return;
    _amplitudeSubscription = stream.listen(
      (amplitude) => add(AudioAmplitudeUpdated(amplitude)),
      onError: (_) {}, // 振幅错误不影响录音主流程
    );
  }

  /// 取消音量订阅并重置振幅
  void _cancelAmplitudeSubscription() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  /// 更新实时音量
  void _onAmplitudeUpdated(
    AudioAmplitudeUpdated event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(amplitude: event.amplitude));
  }

  /// 开始流式录音（带实时转写）
  Future<void> _onStartStreamingRecording(
    AudioStartStreamingRecording event,
    Emitter<AudioState> emit,
  ) async {
    debugPrint('AudioBloc: _onStartStreamingRecording called');

    // 防止重复触发：如果已经在录音、正在连接中，直接返回
    if (_isConnecting || state.isRecording || state.status == RecordingStatus.streamingRecording) {
      debugPrint('AudioBloc: Already recording or connecting, ignoring duplicate start request');
      return;
    }

    if (!state.hasPermission) {
      debugPrint('AudioBloc: No permission for streaming');
      emit(state.copyWith(
        status: RecordingStatus.permissionDenied,
        errorMessage: '没有录音权限',
      ));
      return;
    }

    // 如果没有ASR客户端，降级到普通录音
    if (asrClient == null) {
      debugPrint('AudioBloc: No ASR client, fallback to normal recording');
      add(const AudioStartRecording());
      return;
    }

    // 设置连接中标志，防止重复触发
    _isConnecting = true;
    _sessionToken = Object();

    // 如果已有取消请求（连接前就松开），直接退出
    if (_cancelRequested) {
      _cancelRequested = false;
      _isConnecting = false;
      _sessionToken = null;
      return;
    }

    _wasCanceled = false;

    try {
      // 1. 连接WebSocket
      debugPrint('AudioBloc: Connecting to ASR WebSocket...');
      await asrClient!.connect(
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );

      debugPrint('AudioBloc: ASR WebSocket connected');

      // 如果连接期间用户已取消录音，直接退出
      if (_cancelRequested) {
        _isConnecting = false;
        _cancelRequested = false;
        await _cleanupStreamingResources();
        emit(state.copyWith(
          status: RecordingStatus.ready,
          isWebSocketConnected: false,
          errorMessage: null,
          clearTranscription: true,
        ));
        return;
      }

      // 更新状态为流式录音中
      emit(state.copyWith(
        status: RecordingStatus.streamingRecording,
        isWebSocketConnected: true,
        realtimeTranscription: '',
        isTranscriptionFinal: false,
        duration: 0.0,
        audioPath: null,
        errorMessage: null,
        amplitude: 0.0,
      ));

      // 2. 监听ASR响应
      // 捕获本次会话 token：错误事件携带此 token，_onStreamError 可区分新旧录音
      final capturedToken = _sessionToken;
      _asrResponseSubscription = asrClient!.responses.listen(
        (response) {
          debugPrint('AudioBloc: Received ASR response: ${response.text}, isFinal: ${response.isFinal}');
          if (response.success && response.text != null) {
            add(AudioUpdateStreamTranscription(
              response.text!,
              isFinal: response.isFinal,
            ));
          } else if (!response.success) {
            debugPrint('AudioBloc: ASR error: ${response.error}');
            add(AudioStreamError(response.error ?? 'ASR识别失败', sessionToken: capturedToken));
          }
        },
        onError: (error) {
          debugPrint('AudioBloc: ASR stream error: $error');
          add(AudioStreamError('ASR服务错误: $error', sessionToken: capturedToken));
        },
      );

      // 3. 开始流式录音（必须先启动录音，_startAmplitudePoll() 才会创建 broadcast stream）
      final success = await audioRepository.startStreamingRecording();
      if (!success) {
        throw Exception('启动流式录音失败');
      }

      debugPrint('AudioBloc: Streaming recording started');

      // 如果开始录音后用户已取消，立刻清理并退出
      if (_cancelRequested) {
        _cancelRequested = false;
        await _cleanupStreamingResources();
        emit(state.copyWith(
          status: RecordingStatus.ready,
          isWebSocketConnected: false,
          errorMessage: null,
          clearTranscription: true,
        ));
        return;
      }

      // 订阅实时音量（在 startStreamingRecording() 之后订阅，此时 broadcast stream 已就绪）
      _subscribeAmplitude();

      // 4. 转发音频数据到ASR
      final audioStream = audioRepository.getAudioStream();
      if (audioStream == null) {
        throw Exception('无法获取音频流');
      }

      _audioStreamSubscription = audioStream.listen(
        (chunk) async {
          try {
            await asrClient!.sendAudio(Uint8List.fromList(chunk));
          } catch (e) {
            AppLogger.e('AudioBloc: 发送音频分片失败', e);
          }
        },
        onError: (error) {
          debugPrint('AudioBloc: Audio stream error: $error');
          add(AudioStreamError('音频流错误: $error', sessionToken: capturedToken));
        },
      );

      // 启动时长计时器
      _startDurationTimer();

      // 连接完成，重置标志
      _isConnecting = false;

      debugPrint('AudioBloc: Streaming recording fully initialized');
    } catch (e) {
      // 重置连接标志
      _isConnecting = false;

      // 如果是取消导致的中断，不做降级处理
      if (_cancelRequested) {
        _cancelRequested = false;
        await _cleanupStreamingResources();
        emit(state.copyWith(
          status: RecordingStatus.ready,
          isWebSocketConnected: false,
          errorMessage: null,
          clearTranscription: true,
        ));
        return;
      }

      // 流式录音失败，降级到普通录音
      debugPrint('AudioBloc: Streaming failed, fallback to normal recording: $e');

      // 清理资源
      await _cleanupStreamingResources();

      emit(state.copyWith(
        status: RecordingStatus.initial,
        isWebSocketConnected: false,
        errorMessage: '实时转写不可用，将使用离线模式',
      ));

      // 触发普通录音
      add(const AudioStartRecording());
    }
  }

  /// 更新实时转写文本
  void _onUpdateStreamTranscription(
    AudioUpdateStreamTranscription event,
    Emitter<AudioState> emit,
  ) {
    debugPrint('AudioBloc: Updating transcription: ${event.text}, isFinal: ${event.isFinal}');
    emit(state.copyWith(
      realtimeTranscription: event.text,
      isTranscriptionFinal: event.isFinal,
    ));
  }

  /// 处理流式错误
  Future<void> _onStreamError(
    AudioStreamError event,
    Emitter<AudioState> emit,
  ) async {
    // ── 会话校验：过滤上一次录音残留的过期错误事件 ─────────────────────────
    // 竞争场景：第一次录音结束时服务端关闭 WebSocket，产生 AudioStreamError；
    // 若用户快速再次录制，该事件可能在第二次录音已启动后才被处理，
    // 导致 _onStreamError 断开第二次录音的 WebSocket。
    // 携带 sessionToken 后可用 identical() 精确过滤。
    if (event.sessionToken != null &&
        !identical(event.sessionToken, _sessionToken)) {
      debugPrint(
        'AudioBloc: 忽略过期的流式错误（会话不匹配）: ${event.error}',
      );
      return;
    }
    debugPrint('AudioBloc: Stream error: ${event.error}');

    // 保持录音状态，但断开WebSocket
    await _asrResponseSubscription?.cancel();
    _asrResponseSubscription = null;

    try {
      await asrClient?.disconnect();
    } catch (e) {
      debugPrint('AudioBloc: Error disconnecting ASR: $e');
    }

    emit(state.copyWith(
      isWebSocketConnected: false,
      realtimeTranscription: state.realtimeTranscription ?? '转写服务暂时不可用',
    ));
  }

  /// 完成流式录音
  Future<void> _onFinalizeStreaming(
    AudioFinalizeStreaming event,
    Emitter<AudioState> emit,
  ) async {
    debugPrint('AudioBloc: Finalizing streaming recording');
    _stopDurationTimer();
    _cancelAmplitudeSubscription(); // 立即停止音量采样，避免占用音频会话
    final session = _sessionToken;

    if (_wasCanceled || _cancelRequested) {
      await _cleanupStreamingResources();
      emit(state.copyWith(
        status: RecordingStatus.ready,
        audioPath: null,
        isWebSocketConnected: false,
        clearTranscription: true,
      ));
      _wasCanceled = false;
      _cancelRequested = false;
      if (_sessionToken == session) {
        _sessionToken = null;
      }
      return;
    }

    emit(state.copyWith(status: RecordingStatus.processing));

    // ── 第一步：ASR 收尾（非致命，失败不阻止录音停止）──────────────────────
    // WebSocket 可能因网络波动在 onDone 里已被关闭（_channel = null），
    // 但 BLoC 状态的 isWebSocketConnected 可能仍为 true，
    // 因此 finishAudio() 可能抛 "Not connected" 异常。
    // 此处独立 catch，确保异常不跳过后续的 stopRecording()。
    try {
      if (asrClient != null && state.isWebSocketConnected) {
        debugPrint('AudioBloc: Sending finish signal to ASR');
        await asrClient!.finishAudio();
        // 等待短暂时间以接收最终转写结果
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // ASR 收尾失败不影响后续停止录音，仅记录日志
      debugPrint('AudioBloc: ASR finishAudio failed (non-fatal): $e');
    }

    // ── 第二步：停止录音（必须执行，无论 ASR 是否成功）──────────────────────
    try {
      // 3. 停止录音
      final audioPath = await audioRepository.stopRecording();
      debugPrint('AudioBloc: Recording stopped, path: $audioPath');

      // 4. 清理流资源
      await _cleanupStreamingResources();

      // 5. 更新状态为完成
      if (audioPath != null) {
        if (_sessionToken != session || session == null) {
          return;
        }
        emit(state.copyWith(
          status: RecordingStatus.completed,
          audioPath: audioPath,
          isWebSocketConnected: false,
        ));
        _sessionToken = null;
      } else {
        emit(state.copyWith(
          status: RecordingStatus.error,
          errorMessage: '录音保存失败',
          isWebSocketConnected: false,
        ));
      }
    } catch (e) {
      debugPrint('AudioBloc: Error stopping recording: $e');
      await _cleanupStreamingResources();
      emit(state.copyWith(
        status: RecordingStatus.error,
        errorMessage: '结束录音失败: $e',
        isWebSocketConnected: false,
      ));
    }
  }

  /// 清理流式资源
  Future<void> _cleanupStreamingResources() async {
    debugPrint('AudioBloc: Cleaning up streaming resources');

    // 重置连接标志
    _isConnecting = false;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    await _asrResponseSubscription?.cancel();
    _asrResponseSubscription = null;

    try {
      await asrClient?.disconnect();
    } catch (e) {
      debugPrint('AudioBloc: Error disconnecting ASR during cleanup: $e');
    }
  }

  /// 预热录音相关资源
  Future<void> _onWarmUp(
    AudioWarmUp event,
    Emitter<AudioState> emit,
  ) async {
    try {
      await audioRepository.warmUp();
    } catch (_) {
      // 预热失败不影响主流程
    }
  }

  @override
  Future<void> close() {
    _stopDurationTimer();
    _cancelAmplitudeSubscription();
    _cleanupStreamingResources();
    return super.close();
  }
}
