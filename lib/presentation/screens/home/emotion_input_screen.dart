import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/nvc_analysis.dart';
import '../../../domain/entities/deep_analysis_result.dart';
import '../../../l10n/app_localizations.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_event.dart';
import '../../bloc/audio/audio_state.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_event.dart';
import '../../bloc/record/record_state.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../../widgets/nvc_analyzing_modal.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../../widgets/nvc_error_dialog.dart';
import '../../widgets/record_date_time_picker.dart';
import '../settings/settings_screen.dart';

enum _PendingSubmitAction {
  none,
  saveOnly,
  analyzeNvc,
}

class EmotionInputScreen extends StatefulWidget {
  final bool autoStartRecording;

  const EmotionInputScreen({
    super.key,
    this.autoStartRecording = false,
  });

  @override
  State<EmotionInputScreen> createState() => _EmotionInputScreenState();
}

class _EmotionInputScreenState extends State<EmotionInputScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _recordingFxController;
  AudioBloc? _audioBloc;

  bool _didAutoStartRecording = false;
  bool _requestedAutoPermission = false;
  bool _pendingManualStartAfterPermission = false;
  bool _waitingOfflineTranscription = false;
  bool _isSubmittingRecord = false;
  bool _isAnalyzingNVC = false;
  bool _isAnalyzingModalVisible = false;
  bool _isVoiceInputMode = false;
  String _voicePrefixText = '';
  String? _latestAudioPath;
  String? _lastAudioError;
  // 用户手动通过日期选择器选择的时间；null 表示未手动选过，保存时取 DateTime.now()
  DateTime? _manuallyPickedDateTime;
  _PendingSubmitAction _pendingSubmitAction = _PendingSubmitAction.none;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _recordingFxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _tryAutoStartRecording();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioBloc = context.read<AudioBloc>();
  }

  @override
  void dispose() {
    final audioState = _audioBloc?.state;
    if (audioState?.isRecording == true) {
      _audioBloc?.add(const AudioCancelRecording());
    }
    _textController.dispose();
    _focusNode.dispose();
    _recordingFxController.dispose();
    super.dispose();
  }

  String get _inputText => _textController.text.trim();

  void _setTextFromASR(String text) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;
    final merged = _voicePrefixText.isEmpty
        ? normalizedText
        : '$_voicePrefixText\n$normalizedText';
    if (_textController.text == merged) return;
    _textController.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: merged.length),
    );
  }

  void _showHint(String message, {Color? iconColor, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon ?? Icons.info_outline,
                color: iconColor ?? AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _tryAutoStartRecording() {
    if (!widget.autoStartRecording || _didAutoStartRecording) return;
    final audioState = context.read<AudioBloc>().state;
    if (!audioState.hasPermission) {
      if (!_requestedAutoPermission) {
        _requestedAutoPermission = true;
        context.read<AudioBloc>().add(const AudioRequestPermission());
      }
      return;
    }
    _requestedAutoPermission = false;
    _didAutoStartRecording = true;
    _startRecording();
  }

  void _startRecording() {
    final audioState = context.read<AudioBloc>().state;
    if (audioState.isRecording) return;
    if (!audioState.hasPermission) {
      _pendingManualStartAfterPermission = true;
      context.read<AudioBloc>().add(const AudioRequestPermission());
      _showHint(_l10n.emotionGrantPermissionFirst);
      return;
    }
    _pendingManualStartAfterPermission = false;
    _latestAudioPath = null;
    _waitingOfflineTranscription = false;
    _isVoiceInputMode = true;
    _voicePrefixText = _textController.text.trim();
    // 重置波形物理状态，每次录音从干净直线开始
    _waveH.fillRange(0, _kWaveNodes, 0.0);
    _waveV.fillRange(0, _kWaveNodes, 0.0);
    _displayAmplitude = 0.0;
    _exciteFrame = 0;
    _particles.clear();
    context.read<AudioBloc>().add(const AudioStartStreamingRecording());
  }

  void _stopRecording(AudioState audioState) {
    if (!audioState.isRecording) return;
    _isVoiceInputMode = false;
    if (audioState.isStreamingRecording) {
      context.read<AudioBloc>().add(const AudioFinalizeStreaming());
    } else {
      context.read<AudioBloc>().add(const AudioStopRecording());
    }
  }

  void _toggleRecording(AudioState audioState) {
    if (audioState.isRecording) {
      _stopRecording(audioState);
    } else {
      _startRecording();
    }
  }

  void _submitOnlyRecord() {
    final text = _inputText;
    if (text.isEmpty) {
      _showHint(_l10n.emotionEnterContentBeforeSave);
      return;
    }

    setState(() {
      _isSubmittingRecord = true;
    });

    context.read<RecordBloc>().add(
          RecordCreateQuickNote(
            audioPath: _latestAudioPath,
            mode: ProcessingMode.onlyRecord,
            transcription: text,
            // 优先用用户手动选定的时间；未选则取当前时刻（保存时），
            // 避免用打开页面的时刻作为记录时间（录了很长的音时会相差几分钟）
            createdAt: _manuallyPickedDateTime ?? DateTime.now(),
          ),
        );
  }

  Future<void> _pickRecordDateTime() async {
    final pickedDateTime = await showRecordDateTimePicker(
      context: context,
      initialDateTime: _manuallyPickedDateTime ?? DateTime.now(),
    );

    if (pickedDateTime == null || !mounted) {
      return;
    }

    setState(() {
      _manuallyPickedDateTime = pickedDateTime;
    });
  }

  void _showAnalyzingModal(String transcription) {
    if (_isAnalyzingModalVisible) return;
    _isAnalyzingModalVisible = true;
    NVCAnalyzingModal.show(
      context: context,
      transcription: transcription,
    ).then((_) {
      _isAnalyzingModalVisible = false;
    });
  }

  void _hideAnalyzingModal() {
    if (!_isAnalyzingModalVisible) return;
    _isAnalyzingModalVisible = false;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _startNVCAnalyze() {
    final text = _inputText;
    if (text.isEmpty) {
      _showHint(_l10n.emotionEnterContentBeforeAnalyze);
      return;
    }

    setState(() {
      _isAnalyzingNVC = true;
    });

    _showAnalyzingModal(text);
    context.read<RecordBloc>().add(RecordAnalyzeNVC(text));
  }

  Future<void> _handleAIAuthRequest(RecordState state) async {
    final result = await AIAuthDialog.show(context: context);
    if (!mounted) return;

    if (result == true) {
      await getIt<AIAuthService>().grant();
      if (!mounted) return;
      final text = _inputText;
      if (text.isEmpty) {
        setState(() => _isAnalyzingNVC = false);
        _showHint(_l10n.emotionEmptyInputCannotContinue);
        return;
      }
      _showAnalyzingModal(text);
      context.read<RecordBloc>().add(RecordAnalyzeNVC(text));
      return;
    }

    setState(() => _isAnalyzingNVC = false);
    _showAuthDeniedGuidance();
  }

  void _showAuthDeniedGuidance() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_l10n.aiNeedsAuthSnackbar),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: _l10n.goToSettings,
          textColor: AppColors.accent,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ),
    );
  }

  void _saveWithNVCAnalysis(
    NVCAnalysis analysis, {
    DateTime? createdAt,
    String? transcription,
    List<DeepAnalysisResult> deepAnalyses = const [],
  }) {
    final text = (transcription ?? _inputText).trim();
    if (text.isEmpty) {
      _showHint(_l10n.emotionEmptyInputCannotSave);
      return;
    }

    setState(() {
      _isSubmittingRecord = true;
    });
    _showHint(
      _l10n.homeSavingRecord,
      icon: Icons.hourglass_empty,
      iconColor: AppColors.warning,
    );

    context.read<RecordBloc>().add(
          RecordCreateQuickNote(
            audioPath: _latestAudioPath,
            mode: ProcessingMode.withNVC,
            transcription: text,
            nvcAnalysis: analysis,
            createdAt: createdAt ?? _manuallyPickedDateTime ?? DateTime.now(),
            deepAnalyses: deepAnalyses,
          ),
        );
  }

  void _tryExecutePendingSubmit() {
    if (_pendingSubmitAction == _PendingSubmitAction.none) return;
    if (_waitingOfflineTranscription && _inputText.isEmpty) return;

    final action = _pendingSubmitAction;
    _pendingSubmitAction = _PendingSubmitAction.none;

    if (action == _PendingSubmitAction.saveOnly) {
      _submitOnlyRecord();
    } else if (action == _PendingSubmitAction.analyzeNvc) {
      _startNVCAnalyze();
    }
  }

  void _onTapComplete(AudioState audioState) {
    if (_isSubmittingRecord || _isAnalyzingNVC) return;
    if (audioState.isRecording) {
      _pendingSubmitAction = _PendingSubmitAction.saveOnly;
      _stopRecording(audioState);
      _showHint(_l10n.emotionFinishingRecording);
      return;
    }
    _submitOnlyRecord();
  }

  void _onTapAnalyze(AudioState audioState) {
    if (_isSubmittingRecord || _isAnalyzingNVC) return;
    if (audioState.isRecording) {
      _pendingSubmitAction = _PendingSubmitAction.analyzeNvc;
      _stopRecording(audioState);
      _showHint(_l10n.emotionFinishingRecording);
      return;
    }
    _startNVCAnalyze();
  }

  void _handleAudioState(AudioState audioState) {
    _tryAutoStartRecording();
    if (_pendingManualStartAfterPermission && audioState.hasPermission) {
      _startRecording();
    }
    if (audioState.isRecording) {
      if (!_recordingFxController.isAnimating) {
        _recordingFxController.repeat();
      }
    } else if (_recordingFxController.isAnimating) {
      _recordingFxController.stop();
      _recordingFxController.value = 0;
    }

    final transcription = audioState.realtimeTranscription?.trim();
    if (_isVoiceInputMode &&
        audioState.isRecording &&
        transcription != null &&
        transcription.isNotEmpty) {
      _setTextFromASR(transcription);
    }

    if (audioState.isCompleted && audioState.audioPath != null) {
      _latestAudioPath = audioState.audioPath;
      final streamText = audioState.realtimeTranscription?.trim() ?? '';
      if (streamText.isEmpty) {
        _waitingOfflineTranscription = true;
        context.read<RecordBloc>().add(RecordTranscribe(audioState.audioPath!));
      }
      _tryExecutePendingSubmit();
    }

    if (audioState.hasError &&
        audioState.errorMessage != null &&
        audioState.errorMessage != _lastAudioError) {
      _lastAudioError = audioState.errorMessage;
      _showHint(audioState.errorMessage!,
          icon: Icons.error_outline, iconColor: const Color(0xFFEF5350));
    }
  }

  void _handleRecordState(RecordState recordState) {
    if (_waitingOfflineTranscription) {
      final transcribed = recordState.transcription?.trim();
      if (transcribed != null &&
          transcribed.isNotEmpty &&
          transcribed != '正在转写中...') {
        _waitingOfflineTranscription = false;
        _setTextFromASR(transcribed);
        _tryExecutePendingSubmit();
      } else if (recordState.hasTranscriptionError) {
        _waitingOfflineTranscription = false;
        _pendingSubmitAction = _PendingSubmitAction.none;
        _showHint(
          recordState.transcriptionErrorMessage ??
              _l10n.emotionTranscriptionManualFallback,
          icon: Icons.error_outline,
          iconColor: const Color(0xFFEF5350),
        );
      }
    }

    if (recordState.status == RecordStatus.needsAIAuth && _isAnalyzingNVC) {
      _hideAnalyzingModal();
      _handleAIAuthRequest(recordState);
      return;
    }

    if (recordState.status == RecordStatus.analyzed &&
        recordState.nvcAnalysis != null &&
        _isAnalyzingNVC) {
      _hideAnalyzingModal();
      setState(() => _isAnalyzingNVC = false);
      final analyzedText = _inputText;
      NVCConfirmationModal.show(
        context: context,
        initialAnalysis: recordState.nvcAnalysis!,
        transcription: analyzedText,
        initialDateTime: _manuallyPickedDateTime ?? DateTime.now(),
        onRevert: _submitOnlyRecord,
      ).then((result) {
        if (!mounted || result == null) return;
        if (result.action == NVCModalAction.confirm &&
            result.analysis != null) {
          _saveWithNVCAnalysis(
            result.analysis!,
            createdAt: result.selectedDateTime,
            transcription: analyzedText,
            deepAnalyses: result.deepAnalyses,
          );
        }
      });
      return;
    }

    if (recordState.status == RecordStatus.error) {
      if (_isAnalyzingNVC) {
        _hideAnalyzingModal();
        setState(() => _isAnalyzingNVC = false);
        NVCErrorDialog.show(context: context).then((action) {
          if (!mounted || action == null) return;
          if (action == NVCErrorAction.retry) {
            _startNVCAnalyze();
          } else if (action == NVCErrorAction.saveText) {
            _submitOnlyRecord();
          }
        });
        return;
      }
      if (_isSubmittingRecord) {
        setState(() => _isSubmittingRecord = false);
        _showHint(recordState.errorMessage ?? _l10n.saveFailedRetry,
            icon: Icons.error_outline, iconColor: const Color(0xFFEF5350));
      }
      return;
    }

    if (recordState.status == RecordStatus.success &&
        recordState.latestRecord != null &&
        _isSubmittingRecord) {
      setState(() => _isSubmittingRecord = false);
      _showHint(_l10n.homeRecordSaved,
          icon: Icons.check_circle, iconColor: const Color(0xFF4CAF50));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioState = context.watch<AudioBloc>().state;
    final isBusy = _isSubmittingRecord || _isAnalyzingNVC;
    final isRecording = audioState.isRecording;

    return MultiBlocListener(
      listeners: [
        BlocListener<AudioBloc, AudioState>(
          listener: (_, state) => _handleAudioState(state),
        ),
        BlocListener<RecordBloc, RecordState>(
          listener: (_, state) => _handleRecordState(state),
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF3EFE8),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF3F3B37),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _l10n.emotionInputTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.pageTitle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF36312D),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _pickRecordDateTime,
                      tooltip: _l10n.recordPickSaveDateTooltip,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(40, 40),
                        backgroundColor: const Color(0xFFECE6DE),
                        foregroundColor: const Color(0xFF8F6B4D),
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: Color(0xFFCFC4B5),
                            width: 0.9,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _GridPaperPainter(),
                          ),
                        ),
                      ),
                      TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: null,
                        expands: true,
                        style: AppTypography.transcriptionBody.copyWith(
                          fontSize: 19,
                          color: const Color(0xFF3E3934),
                          height: 1.58,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: _l10n.emotionInputHint,
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFC3BCB3),
                            height: 1.32,
                            fontFamily: AppTypography.sansFamily,
                            fontFamilyFallback: ['PingFang SC', 'Roboto'],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final isCompact =
                        constraints.maxWidth < 430 || textScale > 1.1;

                    final saveButton = _buildFooterActionButton(
                      label: _l10n.emotionInputSave,
                      icon: Icons.keyboard_arrow_down_rounded,
                      foregroundColor: const Color(0xFF5A524A),
                      backgroundColor: const Color(0xFFECE6DE),
                      borderColor: const Color(0xFFCFC4B5),
                      onPressed:
                          isBusy ? null : () => _onTapComplete(audioState),
                    );
                    final analyzeButton = _buildFooterActionButton(
                      label: _l10n.emotionInputAnalyze,
                      icon: Icons.auto_awesome_outlined,
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFD49A72),
                      borderColor: const Color(0xFFC8865D),
                      iconSize: 15,
                      fontWeight: FontWeight.w700,
                      onPressed:
                          isBusy ? null : () => _onTapAnalyze(audioState),
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _buildRecordingButton(
                                isBusy: isBusy,
                                isRecording: isRecording,
                                audioState: audioState,
                              ),
                              const SizedBox(width: 10),
                              _buildVoiceWaveform(
                                isRecording: isRecording,
                                targetAmplitude: audioState.amplitude,
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: saveButton),
                              const SizedBox(width: 10),
                              Expanded(child: analyzeButton),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        _buildRecordingButton(
                          isBusy: isBusy,
                          isRecording: isRecording,
                          audioState: audioState,
                        ),
                        const SizedBox(width: 10),
                        _buildVoiceWaveform(
                          isRecording: isRecording,
                          targetAmplitude: audioState.amplitude,
                        ),
                        const Spacer(),
                        SizedBox(width: 92, child: saveButton),
                        const SizedBox(width: 10),
                        SizedBox(width: 124, child: analyzeButton),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingButton({
    required bool isBusy,
    required bool isRecording,
    required AudioState audioState,
  }) {
    return GestureDetector(
      onTap: isBusy ? null : () => _toggleRecording(audioState),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: AnimatedBuilder(
            animation: _recordingFxController,
            builder: (context, child) {
              // 红点呼吸：sin 映射到 0.55~1.0，平滑闪烁而非硬切
              final dotOpacity = isRecording
                  ? math.sin(_recordingFxController.value * math.pi * 2).abs() *
                          0.45 +
                      0.55
                  : 0.0;

              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isRecording
                      ? const Color(0xFFEAE1D5)
                      : const Color(0xFFEFE9E0),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isRecording
                        ? const Color(0xFFD2A87A)
                        : const Color(0xFFCCC2B5),
                    width: 1.0,
                  ),
                ),
                child: isRecording
                    // ── 录制中：中心红点闪烁 ──────────────────────────
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935)
                                .withValues(alpha: dotOpacity),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE53935)
                                    .withValues(alpha: dotOpacity * 0.45),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      )
                    // ── 待机：麦克风图标 ──────────────────────────────
                    : const Icon(
                        Icons.mic_none_rounded,
                        size: 20,
                        color: Color(0xFF7A6C5F),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 帧级平滑振幅（避免 80ms 采样间隔引起的跳变）
  double _displayAmplitude = 0.0;
  // 弹簧物理节点：每个节点独立受激振动，产生有机随机波形
  static const int _kWaveNodes = 18; // 宽度扩大后增至 18 节点保持曲线密度
  final List<double> _waveH = List.filled(_kWaveNodes, 0.0); // 归一化高度 -1~1
  final List<double> _waveV = List.filled(_kWaveNodes, 0.0); // 速度
  final _rng = math.Random();
  int _exciteFrame = 0; // 节拍计时器：控制激发节奏，避免同帧多点乱抖

  // 粒子系统：波纹上下随音量飘动的小亮点
  final List<_WaveParticle> _particles = [];

  /// 每帧更新粒子：老化 + 按音量概率生成新粒子。
  void _updateParticles(double amp) {
    // 老化现有粒子，移除生命耗尽的
    for (final p in _particles) {
      p.life -= 1.0;
    }
    _particles.removeWhere((p) => p.life <= 0);

    // 音量低于阈值时不生成新粒子（完全静音 = 无粒子）
    if (amp <= 0.05) return;

    // 生成概率随音量 1.5 次方增长：小声时极少，大声时明显
    final spawnProb = math.pow(amp, 1.5) * 0.22;
    if (_rng.nextDouble() < spawnProb) {
      final above = _rng.nextBool();
      _particles.add(_WaveParticle(
        x: 0.08 + _rng.nextDouble() * 0.84, // 避开 ShaderMask 淡出边缘
        yOff: (above ? 1.0 : -1.0) *
            (0.20 + _rng.nextDouble() * 0.45), // 偏离波面 20~65%
        maxLife: 28.0 + _rng.nextDouble() * 24.0, // 0.47~0.87 秒
        radius: 0.7 + _rng.nextDouble() * 1.1, // 0.7~1.8 px
      ));
      // 上限 14 个，避免画面过满
      if (_particles.length > 14) {
        _particles.removeRange(0, _particles.length - 14);
      }
    }
  }

  /// 每帧推进弹簧物理。
  ///
  /// 设计目标：有声音时波形平缓起伏，无声音时完全平线。
  ///
  /// 关键参数说明：
  ///   stiffness 0.014 → 弹簧更软，振荡周期 ~1s，宏观感觉慢
  ///   drag      0.97  → 高阻尼，振动半衰期 ~0.38s，波形持续时间长
  ///   coupling  0.018 → 适中耦合，行波传播但不激发高频"闪烁"模式
  ///   interval  12~32 帧 → 正常说话约 2~3 次/s（之前最快 15 次/s）
  ///   Gaussian  5节点平滑凸包激发 → 只激发长波低频模式，天然过滤抖动感
  void _stepWave(double amp) {
    const stiffness = 0.008; // 超软弹簧 → 基频 ~0.85 Hz，振荡更慢
    const drag = 0.980; // 高阻尼 → 半衰期 ~0.57 s，起伏更悠长
    const coupling = 0.012; // 更低耦合 → 高频模式上限降至 ~2.0 Hz

    // ── 物理步进：耦合 + 弹簧恢复 + 阻尼 ────────────────────────────────
    for (int i = 0; i < _kWaveNodes; i++) {
      final left = i > 0 ? _waveH[i - 1] : _waveH[i];
      final right = i < _kWaveNodes - 1 ? _waveH[i + 1] : _waveH[i];
      _waveV[i] += coupling * (left + right - 2.0 * _waveH[i]);
      _waveV[i] -= _waveH[i] * stiffness;
      _waveV[i] *= drag;
      _waveH[i] = (_waveH[i] + _waveV[i]).clamp(-1.0, 1.0);
    }

    // ── 节拍激发：在旧 clamp(12,32) 基础上直接翻倍 → clamp(24,64) ───────
    // amp=0.5 时约 44 帧间隔（~1.4 次/s），最快 24 帧（~2.5 次/s）
    if (amp > 0.02) {
      _exciteFrame++;
      final interval = (90 - amp * 50).round().clamp(40, 90);
      if (_exciteFrame >= interval) {
        _exciteFrame = 0;
        final center = 2 + _rng.nextInt(_kWaveNodes - 4);
        final impulse = (_rng.nextDouble() * 2 - 1) * amp * 0.25;
        // 高斯 5 点扩散，只激发长波低频模式
        _waveV[center - 2] += impulse * 0.15;
        _waveV[center - 1] += impulse * 0.55;
        _waveV[center] += impulse * 1.00;
        _waveV[center + 1] += impulse * 0.55;
        _waveV[center + 2] += impulse * 0.15;
      }
    } else {
      _exciteFrame = 0;
    }
  }

  Widget _buildVoiceWaveform({
    required bool isRecording,
    required double targetAmplitude,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isRecording ? 1.0 : 0.0,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.14, 0.86, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SizedBox(
          width: 160,
          height: 32,
          child: AnimatedBuilder(
            animation: _recordingFxController,
            builder: (context, _) {
              // 以 3% 的速率追踪目标振幅，更柔和地响应音量变化
              _displayAmplitude += (targetAmplitude - _displayAmplitude) * 0.03;
              // 弹簧物理步进
              _stepWave(_displayAmplitude);
              // 粒子系统：随音量更新
              _updateParticles(_displayAmplitude);
              return CustomPaint(
                painter: _VoiceWavePainter(
                  heights: List<double>.of(_waveH),
                  amplitude: _displayAmplitude,
                  color: const Color(0xFFD39C76),
                  // 传粒子副本，避免 paint 期间列表被修改
                  particles: List<_WaveParticle>.of(_particles),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActionButton({
    required String label,
    required IconData icon,
    required Color foregroundColor,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback? onPressed,
    double iconSize = 17,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return SizedBox(
      height: 42,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
            side: BorderSide(
              color: borderColor,
              width: 0.9,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: foregroundColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.actionLabel.copyWith(
                  fontSize: 16,
                  color: foregroundColor,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹簧物理声波可视化。
///
/// 14 个独立弹簧节点，声音随机激发各节点振动，
/// 节点间用 Catmull-Rom 样条平滑连接。
/// 静音时所有节点自然归零 → 完美水平直线；
/// 有声音时各位置独立起伏，形态有机而不规律。
class _VoiceWavePainter extends CustomPainter {
  /// 各节点归一化高度（-1.0 ~ 1.0），由弹簧物理驱动
  final List<double> heights;

  /// 平滑后的音量（0.0 静音 ~ 1.0 最大），用于 shouldRepaint
  final double amplitude;

  final Color color;

  /// 当前帧的粒子快照
  final List<_WaveParticle> particles;

  _VoiceWavePainter({
    required this.heights,
    required this.amplitude,
    required this.color,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final maxH = size.height * 0.44;
    final mid = size.height / 2;
    final n = heights.length;

    // 将归一化节点映射到画布坐标
    final pts = List<Offset>.generate(n, (i) {
      final x = size.width * i / (n - 1);
      final y = mid - heights[i] * maxH;
      return Offset(x, y);
    });

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── 主波：实色 ─────────────────────────────────────────────────────────
    paint
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: 0.84);
    canvas.drawPath(_catmullRom(pts, yShift: 0.0), paint);

    // ── 高光波：轻薄偏上，模拟光泽感 ────────────────────────────────────────
    paint
      ..strokeWidth = 1.0
      ..color = color.withValues(alpha: 0.24);
    canvas.drawPath(_catmullRom(pts, yShift: -1.4), paint);

    // ── 粒子：波纹上下的呼吸小亮点 ──────────────────────────────────────────
    if (particles.isNotEmpty) {
      final dotPaint = Paint()..style = PaintingStyle.fill;
      for (final p in particles) {
        // 生命进度 0→1（出生到死亡），用 sin 映射出 "渐亮→渐暗" 的呼吸弧
        final progress = 1.0 - p.life / p.maxLife;
        final alpha = math.sin(progress * math.pi);
        if (alpha <= 0.01) continue;

        // 在粒子 x 处插值波面 y 坐标
        final fIdx = p.x * (n - 1);
        final iLeft = fIdx.floor().clamp(0, n - 2);
        final t = fIdx - iLeft;
        final waveH = heights[iLeft] * (1 - t) + heights[iLeft + 1] * t;
        final waveY = mid - waveH * maxH;

        final cx = p.x * size.width;
        final cy = waveY - p.yOff * maxH; // yOff>0 浮于波面上方，<0 沉于下方

        // 外圈柔光晕（低透明度，营造发光感）
        dotPaint.color = color.withValues(alpha: alpha * 0.30);
        canvas.drawCircle(Offset(cx, cy), p.radius * 2.4, dotPaint);

        // 内核亮点（暖白色，最亮时接近不透明）
        dotPaint.color =
            const Color(0xFFFFF4E8).withValues(alpha: alpha * 0.88);
        canvas.drawCircle(Offset(cx, cy), p.radius, dotPaint);
      }
    }
  }

  /// 将离散控制点转换为 Catmull-Rom 样条 Path。
  /// [yShift] 将整条曲线整体垂直偏移（用于高光层）。
  Path _catmullRom(List<Offset> pts, {required double yShift}) {
    final path = Path();
    if (pts.length < 2) return path;

    final first = Offset(pts[0].dx, pts[0].dy + yShift);
    path.moveTo(first.dx, first.dy);

    for (int i = 0; i < pts.length - 1; i++) {
      // 端点处用自身镜像扩展，确保首尾曲线平滑
      final p0 = pts[i > 0 ? i - 1 : i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i < pts.length - 2 ? i + 2 : i + 1];

      // Catmull-Rom → Bezier 控制点转换
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6 + yShift,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6 + yShift,
      );
      final end = Offset(p2.dx, p2.dy + yShift);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(_VoiceWavePainter old) {
    // 有粒子存在时始终重绘（粒子每帧都在变化）
    if (particles.isNotEmpty || old.particles.isNotEmpty) return true;
    if ((old.amplitude - amplitude).abs() > 0.0005) return true;
    for (int i = 0; i < heights.length; i++) {
      if ((old.heights[i] - heights[i]).abs() > 0.0005) return true;
    }
    return false;
  }
}

/// 波纹粒子数据：一个飘动在波面附近的小亮点。
class _WaveParticle {
  /// 归一化 x 坐标（0~1，对应 SizedBox 宽度）
  final double x;

  /// 相对波面的归一化偏移量（正值 = 波面上方，负值 = 下方）
  final double yOff;

  /// 总生命帧数（出生时 life = maxLife，归零时消亡）
  final double maxLife;

  /// 剩余生命帧数（可变）
  double life;

  /// 圆点半径（像素）
  final double radius;

  _WaveParticle({
    required this.x,
    required this.yOff,
    required this.maxLife,
    required this.radius,
  }) : life = maxLife;
}

class _GridPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;

    final horizontal = Paint()
      ..color = const Color(0xFFBFB7AA).withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    final vertical = Paint()
      ..color = const Color(0xFFBFB7AA).withValues(alpha: 0.07)
      ..strokeWidth = 0.7;

    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), horizontal);
    }

    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), vertical);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
