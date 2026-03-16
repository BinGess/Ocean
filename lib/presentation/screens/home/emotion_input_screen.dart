import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/nvc_analysis.dart';
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
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _recordingFxController;

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
  _PendingSubmitAction _pendingSubmitAction = _PendingSubmitAction.none;

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
  void dispose() {
    final audioState = context.read<AudioBloc>().state;
    if (audioState.isRecording) {
      context.read<AudioBloc>().add(const AudioCancelRecording());
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
                color: iconColor ?? const Color(0xFFFFB74D), size: 20),
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
      _showHint('请先授予录音权限');
      return;
    }
    _pendingManualStartAfterPermission = false;
    _latestAudioPath = null;
    _waitingOfflineTranscription = false;
    _isVoiceInputMode = true;
    _voicePrefixText = _textController.text.trim();
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
      _showHint('请输入内容后再保存');
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
          ),
        );
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
      _showHint('请输入内容后再分析');
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
        _showHint('输入内容为空，无法继续分析');
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
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFFFB74D)),
            SizedBox(width: 8),
            Expanded(
              child: Text('AI功能需要授权才能使用，您可在设置中开启'),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '去设置',
          textColor: const Color(0xFFC4A57B),
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
  }) {
    final text = _inputText;
    if (text.isEmpty) {
      _showHint('输入内容为空，无法保存');
      return;
    }

    setState(() {
      _isSubmittingRecord = true;
    });

    context.read<RecordBloc>().add(
          RecordCreateQuickNote(
            audioPath: _latestAudioPath,
            mode: ProcessingMode.withNVC,
            transcription: text,
            nvcAnalysis: analysis,
            createdAt: createdAt,
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
      _showHint('正在结束录音...');
      return;
    }
    _submitOnlyRecord();
  }

  void _onTapAnalyze(AudioState audioState) {
    if (_isSubmittingRecord || _isAnalyzingNVC) return;
    if (audioState.isRecording) {
      _pendingSubmitAction = _PendingSubmitAction.analyzeNvc;
      _stopRecording(audioState);
      _showHint('正在结束录音...');
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
          recordState.transcriptionErrorMessage ?? '转写失败，请手动补充内容后再试',
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
      NVCConfirmationModal.show(
        context: context,
        initialAnalysis: recordState.nvcAnalysis!,
        transcription: _inputText,
        onRevert: _submitOnlyRecord,
      ).then((result) {
        if (!mounted || result == null) return;
        if (result.action == NVCModalAction.confirm &&
            result.analysis != null) {
          _saveWithNVCAnalysis(
            result.analysis!,
            createdAt: result.selectedDateTime,
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
        _showHint(recordState.errorMessage ?? '保存失败，请重试',
            icon: Icons.error_outline, iconColor: const Color(0xFFEF5350));
      }
      return;
    }

    if (recordState.status == RecordStatus.success &&
        recordState.latestRecord != null &&
        _isSubmittingRecord) {
      setState(() => _isSubmittingRecord = false);
      _showHint('记录已保存',
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
                    Text(
                      '描述下你此刻的心情？',
                      style: AppTypography.pageTitle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF36312D),
                        letterSpacing: -0.1,
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
                        decoration: const InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: '尽情书写，让我帮你分析此刻的心情',
                          hintStyle: TextStyle(
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
                child: Row(
                  children: [
                    _buildRecordingButton(
                      isBusy: isBusy,
                      isRecording: isRecording,
                      audioState: audioState,
                    ),
                    const SizedBox(width: 10),
                    _buildRecordingWaveform(isRecording: isRecording),
                    const Spacer(),
                    SizedBox(
                      width: 88,
                      height: 36,
                      child: TextButton(
                        onPressed:
                            isBusy ? null : () => _onTapComplete(audioState),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFFECE6DE),
                          foregroundColor: const Color(0xFF5A524A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(19),
                            side: const BorderSide(
                              color: Color(0xFFCFC4B5),
                              width: 0.9,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 17),
                            const SizedBox(width: 1),
                            Text(
                              '保存',
                              style: AppTypography.actionLabel.copyWith(
                                fontSize: 16,
                                color: const Color(0xFF5A524A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 112,
                      height: 36,
                      child: TextButton(
                        onPressed:
                            isBusy ? null : () => _onTapAnalyze(audioState),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFFD49A72),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(19),
                            side: const BorderSide(
                              color: Color(0xFFC8865D),
                              width: 0.9,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome_outlined,
                                size: 15, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'NVC分析',
                              style: AppTypography.actionLabel.copyWith(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
        width: 52,
        height: 52,
        child: Center(
          child: AnimatedBuilder(
            animation: _recordingFxController,
            builder: (context, child) {
              final pulse = isRecording
                  ? math.sin(_recordingFxController.value * math.pi * 2).abs()
                  : 0.0;
              return Transform.scale(
                scale: 1 + (0.06 * pulse),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isRecording)
                      Container(
                        width: 44 + (pulse * 5),
                        height: 44 + (pulse * 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD9AD79)
                                .withValues(alpha: 0.35 - (pulse * 0.2)),
                            width: 1.2,
                          ),
                        ),
                      ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isRecording
                            ? const Color(0xFFE3C89F)
                            : const Color(0xFFEFE9E0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRecording
                              ? const Color(0xFFD7AB76)
                              : const Color(0xFFCCC2B5),
                          width: 1.0,
                        ),
                        boxShadow: [
                          if (isRecording)
                            BoxShadow(
                              color: const Color(0xFFE2C392)
                                  .withValues(alpha: 0.18 + (pulse * 0.18)),
                              blurRadius: 8 + (pulse * 4),
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Icon(
                        isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                        size: 18,
                        color: const Color(0xFF7A6C5F),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingWaveform({required bool isRecording}) {
    return SizedBox(
      width: 44,
      height: 22,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isRecording ? 1 : 0,
        child: AnimatedBuilder(
          animation: _recordingFxController,
          builder: (context, _) {
            final t = _recordingFxController.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(5, (index) {
                final phase = t * math.pi * 2 + index * 0.75;
                final factor = 0.35 + (math.sin(phase).abs() * 0.65);
                final height = 6 + (12 * factor);
                return Container(
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD39C76).withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
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
