import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
import '../../../domain/entities/quote.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_state.dart';
import '../../bloc/audio/audio_event.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_state.dart';
import '../../bloc/record/record_event.dart';
import '../../widgets/processing_choice_modal.dart';
import '../../widgets/mood_selection_modal.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../../widgets/nvc_error_dialog.dart';
import '../../widgets/nvc_analyzing_modal.dart';
import '../../widgets/ai_auth_dialog.dart';
import '../settings/settings_screen.dart';
import '../pro/pro_purchase_screen.dart';
import 'emotion_input_screen.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/services/pro_subscription_service.dart';
import '../../../core/services/quote_preloader.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String? _completedAudioPath;
  // 用户编辑后的转写文本 - 用于NVC分析确认页面回显
  String? _editedTranscription;
  List<Quote> _quotes = [];
  bool _quotesLoaded = false;
  int _currentQuoteIndex = 0;
  Timer? _quoteAutoSwitchTimer;
  bool _isQuoteSwitching = false;
  late AnimationController _quoteTransitionController;
  static const _HomeBackgroundPalette _backgroundPalette =
      _HomeBackgroundPalette.defaultPalette;

  // 按钮脉冲动画控制器
  late AnimationController _pulseController;

  // 防止错误弹窗重复显示
  bool _isShowingErrorDialog = false;
  // 记录上次处理的错误消息，避免重复处理同一个错误
  String? _lastHandledError;
  String? _lastHandledTranscriptionError;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  List<String> get _fallbackQuoteTexts {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return const [
        'Observe the moment without judgment',
        'Write slowly. Your heart will catch up',
        'Let this page hold the present',
      ];
    }
    return const [
      '观察当下，不做评判',
      '慢慢写，心会跟上来',
      '把此刻交给这一页',
    ];
  }

  @override
  void initState() {
    super.initState();
    // 注：不在此处加载记录列表，避免与 RecordsScreen 冲突
    // RecordsScreen 会加载完整的记录列表
    // 如果在此处使用 limit:5 加载，会覆盖 RecordsScreen 的完整列表

    // 注：权限和预热已在 AppEntryPoint 开屏期间处理
    // 这里仅作为备用检查，确保权限状态正确
    _checkAndRequestPermission();

    // 加载文案数据
    _loadQuotes();

    // 初始化脉冲动画控制器 - 强化膨胀效果
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // 稍微延长持续时间
    );
    Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _quoteTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
  }

  void _syncRecordEntryPulse(bool isRecording) {
    if (isRecording) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }

    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  /// 加载文案数据（使用QuotePreloader支持离线）
  Future<void> _loadQuotes() async {
    try {
      final preloader = getIt<QuotePreloader>();
      await preloader.preload();
      setState(() {
        _quotes = preloader.getCachedQuotes();
        _currentQuoteIndex = 0;
        _quotesLoaded = true;
      });
      _startQuoteAutoSwitch();
      debugPrint('Successfully loaded ${_quotes.length} quotes from preloader');
    } catch (e) {
      debugPrint('Error loading quotes: $e');
      setState(() => _quotesLoaded = true);
      _quoteAutoSwitchTimer?.cancel();
    }
  }

  void _startQuoteAutoSwitch() {
    _quoteAutoSwitchTimer?.cancel();
    if (_quotes.length <= 1) return;
    _quoteAutoSwitchTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _switchToNextQuote();
    });
  }

  Future<void> _switchToNextQuote() async {
    if (!mounted || _quotes.length <= 1 || _isQuoteSwitching) return;
    _isQuoteSwitching = true;
    await _quoteTransitionController.forward(from: 0);
    if (!mounted) {
      _isQuoteSwitching = false;
      return;
    }
    setState(() {
      _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
    });
    _quoteTransitionController.reset();
    _isQuoteSwitching = false;
  }

  int _positiveModulo(int value, int length) {
    if (length == 0) return 0;
    return ((value % length) + length) % length;
  }

  String _normalizeQuoteText(String text) {
    return text.trim().replaceFirst(RegExp(r'[。！？!?]$'), '');
  }

  String _quoteTextForOffset(int offset) {
    if (_quotes.isEmpty) {
      final fallbackIndex = _positiveModulo(
          _currentQuoteIndex + offset, _fallbackQuoteTexts.length);
      return _fallbackQuoteTexts[fallbackIndex];
    }

    final quoteIndex =
        _positiveModulo(_currentQuoteIndex + offset, _quotes.length);
    return _normalizeQuoteText(_quotes[quoteIndex].content);
  }

  double _lyricScrollProgress() {
    if (!_isQuoteSwitching) return 0.0;

    final raw = _quoteTransitionController.value;
    if (raw < 0.76) {
      return ui.lerpDouble(
        0.0,
        1.0,
        Curves.easeInOutCubicEmphasized.transform(raw / 0.76),
      )!;
    }

    final settle = (raw - 0.76) / 0.24;
    return 1.0 + math.sin(settle * math.pi) * (1.0 - settle) * 0.045;
  }

  double _fitSingleLineQuoteFontSize({
    required BuildContext context,
    required String text,
    required TextStyle style,
    required double maxWidth,
    double minFontSize = 18,
  }) {
    final baseFontSize = style.fontSize ?? 24;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      maxLines: 1,
      ellipsis: '…',
    );

    for (double fontSize = baseFontSize;
        fontSize >= minFontSize;
        fontSize -= 0.5) {
      painter.text = TextSpan(
        text: text,
        style: style.copyWith(fontSize: fontSize),
      );
      painter.layout(maxWidth: maxWidth);
      if (!painter.didExceedMaxLines && painter.width <= maxWidth) {
        return fontSize;
      }
    }

    return minFontSize;
  }

  Widget _buildLyricQuoteViewport() {
    const viewportHeight = 180.0;
    const rowHeight = 60.0;
    final progress = _lyricScrollProgress();

    return ClipRect(
      child: SizedBox(
        height: viewportHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 18,
                      sigmaY: 18,
                    ),
                    child: Container(
                      width: 270,
                      height: rowHeight + 14,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.92,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            const Color(0xFFE8D5C0).withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -rowHeight * (1 + progress)),
              child: Column(
                children: List.generate(5, (index) {
                  final relativePosition = (index - 2) - progress;
                  return _buildLyricQuoteLine(
                    text: _quoteTextForOffset(index - 2),
                    relativePosition: relativePosition,
                    rowHeight: rowHeight,
                  );
                }),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFF5EEE4).withValues(alpha: 0.78),
                        const Color(0xFFF5EEE4).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFFF0E8DC).withValues(alpha: 0.80),
                        const Color(0xFFF0E8DC).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricQuoteLine({
    required String text,
    required double relativePosition,
    required double rowHeight,
  }) {
    if (relativePosition < -1.8 || relativePosition > 1.8) {
      return SizedBox(height: rowHeight);
    }

    final distance = relativePosition.abs().clamp(0.0, 1.8);
    final emphasis = (1.0 - distance).clamp(0.0, 1.0);
    final easedEmphasis = math
        .pow(
          Curves.easeOutCubic.transform(emphasis),
          0.92,
        )
        .toDouble();
    final opacity = ui.lerpDouble(0.36, 1.0, easedEmphasis)!.clamp(0.0, 1.0);
    final baseFontSize = ui.lerpDouble(15.2, 24.0, easedEmphasis)!;
    final scale = ui.lerpDouble(0.92, 1.0, easedEmphasis)!;
    final blur = ui.lerpDouble(0.9, 0.0, easedEmphasis)!;
    final textColor = Color.lerp(
      const Color(0xFFAA9585).withValues(alpha: 0.88),
      const Color(0xFF3D2A1A),
      easedEmphasis,
    )!;
    final verticalNudge = ui.lerpDouble(1.6, 0.0, easedEmphasis)!;
    final shadowBlur = ui.lerpDouble(0.0, 6.0, easedEmphasis)!;
    final shadowYOffset = ui.lerpDouble(0.0, 2.0, easedEmphasis)!;

    return SizedBox(
      height: rowHeight,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, verticalNudge),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textStyle = AppTypography.quoteBody.copyWith(
                    fontSize: baseFontSize,
                    height: 1.0,
                    color: textColor,
                    fontWeight: easedEmphasis > 0.72
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: 0.0,
                    shadows: easedEmphasis > 0.62
                        ? [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.28),
                              blurRadius: shadowBlur,
                              offset: Offset(0, shadowYOffset),
                            ),
                          ]
                        : null,
                  );
                  final fittedFontSize = _fitSingleLineQuoteFontSize(
                    context: context,
                    text: text,
                    style: textStyle,
                    maxWidth: constraints.maxWidth - 16,
                  );
                  final fittedText = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: textStyle.copyWith(fontSize: fittedFontSize),
                    ),
                  );

                  if (blur <= 0.05) {
                    return fittedText;
                  }

                  return ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                    ),
                    child: fittedText,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 备用权限检查（已禁用，避免重复弹窗）
  /// 权限已在 AppEntryPoint 开屏期间请求
  /// 这里不再主动检查，避免触发重复的权限对话框
  void _checkAndRequestPermission() {
    // 不再调用 AudioCheckPermission，因为 record 包的 hasPermission()
    // 在首次调用时会触发系统权限弹窗
    // 权限请求已在 AppEntryPoint 中统一处理
  }

  void _handleRecordComplete(String audioPath) {
    setState(() {
      _completedAudioPath = audioPath;
      _editedTranscription = null; // 清除上次编辑的转写文本
    });
    // 清除上次错误记录，允许新的错误被处理
    _lastHandledError = null;
    _lastHandledTranscriptionError = null;

    // 获取AudioState以检查是否有流式转写结果
    final audioState = context.read<AudioBloc>().state;
    final streamTranscription = audioState.realtimeTranscription;

    // 如果流式转写结果为空，说明可能没有实际内容输入，取消录音
    if (streamTranscription == null || streamTranscription.trim().isEmpty) {
      debugPrint('HomeScreen: 转写结果为空，取消录音');
      _completedAudioPath = null;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(_l10n.homeContentTooShortRetry),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 如果有流式转写结果，直接使用；否则触发传统转写
    if (streamTranscription.isNotEmpty) {
      // 使用流式转写结果，直接显示处理选择模态框
      debugPrint('HomeScreen: 使用流式转写结果: $streamTranscription');
      _showProcessingChoice(streamTranscription);
    } else {
      // 没有流式转写结果，触发传统转写
      debugPrint('HomeScreen: 触发传统转写');
      context.read<RecordBloc>().add(RecordTranscribe(audioPath));

      // 显示处理选择模态框（等待转写完成）
      showModalBottomSheet<ProcessingResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (context) {
          return BlocBuilder<RecordBloc, RecordState>(
            builder: (context, state) {
              return ProcessingChoiceModal(
                transcription: state.transcription ?? '',
                transcriptionErrorMessage: state.transcriptionErrorMessage,
                onSelect: (result) => Navigator.of(context).pop(result),
                onCancel: () => Navigator.of(context).pop(),
              );
            },
          );
        },
      ).then((result) {
        if (result != null && _completedAudioPath != null) {
          _handleProcessingModeSelected(result.mode,
              editedTranscription: result.transcription);
        }
      });
    }
  }

  /// 显示处理选择模态框
  void _showProcessingChoice(String transcription) {
    showModalBottomSheet<ProcessingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) {
        return ProcessingChoiceModal(
          transcription: transcription,
          onSelect: (result) => Navigator.of(context).pop(result),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    ).then((result) {
      if (result != null && _completedAudioPath != null) {
        _handleProcessingModeSelected(result.mode,
            editedTranscription: result.transcription);
      }
    });
  }

  /// 处理AI授权请求
  Future<void> _handleAIAuthRequest(
    BuildContext context,
    RecordState state,
  ) async {
    final result = await AIAuthDialog.show(context: context);

    if (result == true) {
      // 用户同意授权
      await getIt<AIAuthService>().grant();

      // 重新触发AI分析
      if (state.transcription != null && state.transcription!.isNotEmpty) {
        if (!context.mounted) return;
        context.read<RecordBloc>().add(
              RecordAnalyzeNVC(state.transcription!),
            );
      }
    } else {
      // 用户拒绝授权
      if (!context.mounted) return;
      _showAuthDeniedGuidance(context);
    }
  }

  /// 显示拒绝授权引导
  void _showAuthDeniedGuidance(BuildContext context) {
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

  void _handleProcessingModeSelected(ProcessingMode mode,
      {String? editedTranscription}) async {
    if (_completedAudioPath == null) return;

    // 优先使用用户编辑后的转写文本，其次流式转写，最后RecordBloc的转写
    final audioState = context.read<AudioBloc>().state;
    final streamTranscription = audioState.realtimeTranscription;
    final recordTranscription = context.read<RecordBloc>().state.transcription;
    final transcription =
        editedTranscription ?? streamTranscription ?? recordTranscription;

    // 保存编辑后的转写文本，用于NVC分析确认页面回显
    _editedTranscription = transcription;

    switch (mode) {
      case ProcessingMode.onlyRecord:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.bgPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_l10n.homeSavingRecord),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        context.read<RecordBloc>().add(
              RecordCreateQuickNote(
                audioPath: _completedAudioPath!,
                mode: mode,
                transcription: transcription,
              ),
            );
        // _clearCompletedAudio(); // 移至 BlocListener 处理
        break;

      case ProcessingMode.withMood:
        final moods = await MoodSelectionModal.show(context: context);
        if (moods != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.bgPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_l10n.homeSavingRecord),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          context.read<RecordBloc>().add(
                RecordCreateQuickNote(
                  audioPath: _completedAudioPath!,
                  mode: mode,
                  transcription: transcription,
                  selectedMoods: moods,
                ),
              );
          // _clearCompletedAudio(); // 移至 BlocListener 处理
        }
        break;

      case ProcessingMode.withNVC:
        // 检查转写内容是否有效
        if (transcription == null ||
            transcription.isEmpty ||
            transcription == '正在转写中...') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.hourglass_empty,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(_l10n.homeTranscriptionPending),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        // 触发 NVC 分析，分析完成后会在 BlocListener 中处理
        if (transcription.isNotEmpty) {
          // 首先检查 AI 授权
          final aiAuthService = getIt<AIAuthService>();
          final isAuthorized = await aiAuthService.isAuthorized;

          if (!isAuthorized) {
            // 显示 AI 授权对话框
            if (!mounted) return;
            final authResult = await AIAuthDialog.show(context: context);

            if (authResult == true) {
              // 用户同意授权
              await aiAuthService.grant();
            } else {
              // 用户拒绝授权，显示引导提示
              if (!mounted) return;
              _showAuthDeniedGuidance(context);
              return;
            }
          }

          // 授权通过，显示NVC分析加载动画弹窗
          if (!mounted) return;
          NVCAnalyzingModal.show(
            context: context,
            transcription: transcription,
          );
          context.read<RecordBloc>().add(RecordAnalyzeNVC(transcription));
          // 注意：这里不要立即清除 _completedAudioPath，因为后续保存还需要它
        } else {
          // 如果没有转写文本，无法分析，降级为直接保存
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_l10n.homeNoTranscriptionFallback)),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          context.read<RecordBloc>().add(
                RecordCreateQuickNote(
                  audioPath: _completedAudioPath!,
                  mode: ProcessingMode.onlyRecord,
                  transcription: transcription,
                ),
              );
          // _clearCompletedAudio(); // 移至 BlocListener 处理
        }
        break;
    }
  }

  void _clearCompletedAudio() {
    setState(() {
      _completedAudioPath = null;
      _editedTranscription = null;
    });
    _lastHandledTranscriptionError = null;
  }

  Future<void> _openInputScreen({required bool autoStartRecording}) async {
    final audioState = context.read<AudioBloc>().state;
    if (audioState.isRecording) {
      context.read<AudioBloc>().add(const AudioCancelRecording());
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmotionInputScreen(
          autoStartRecording: autoStartRecording,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _quoteTransitionController.dispose();
    _quoteAutoSwitchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    String greeting = _l10n.homeGreetingEvening;
    final hour = now.hour;
    if (hour < 12) {
      greeting = _l10n.homeGreetingMorning;
    } else if (hour < 18) {
      greeting = _l10n.homeGreetingAfternoon;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _backgroundPalette.gradientColors,
            stops: _backgroundPalette.gradientStops,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              right: -80,
              height: 420,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.05,
                      colors: [
                        Colors.white.withValues(alpha: 0.23),
                        Colors.white.withValues(alpha: 0.012),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SoftUITexturePainter(
                    ringColor: _backgroundPalette.ringColor
                        .withValues(alpha: _backgroundPalette.ringAlpha),
                    overlayColor: _backgroundPalette.overlayColor
                        .withValues(alpha: _backgroundPalette.overlayAlpha),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 214,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _backgroundPalette.bottomFogColor.withValues(alpha: 0),
                        _backgroundPalette.bottomFogColor.withValues(
                          alpha: _backgroundPalette.bottomFogMiddleAlpha,
                        ),
                        _backgroundPalette.bottomFogColor,
                      ],
                      stops: const [0.0, 0.56, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            BlocListener<AudioBloc, AudioState>(
              listener: (context, audioState) {
                _syncRecordEntryPulse(audioState.isRecording);
                final isCurrentRoute =
                    ModalRoute.of(context)?.isCurrent ?? false;
                if (!isCurrentRoute) return;
                // 录音完成后处理
                if (audioState.isCompleted && audioState.audioPath != null) {
                  _handleRecordComplete(audioState.audioPath!);
                }

                // 显示错误
                if (audioState.hasError && audioState.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF5350), size: 20),
                          const SizedBox(width: 8),
                          Flexible(child: Text(audioState.errorMessage!)),
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: BlocListener<RecordBloc, RecordState>(
                listener: (context, recordState) {
                  final isCurrentRoute =
                      ModalRoute.of(context)?.isCurrent ?? false;
                  if (!isCurrentRoute) return;
                  if (recordState.isAnalyzed &&
                      recordState.nvcAnalysis != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // 先关闭分析加载动画弹窗
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }

                      if (ModalRoute.of(context)?.isCurrent ?? false) {
                        final messenger = ScaffoldMessenger.of(context);
                        final recordBloc = context.read<RecordBloc>();
                        // 优先使用用户编辑后的转写文本，其次流式转写，最后RecordBloc的转写
                        final audioState = context.read<AudioBloc>().state;
                        final transcription = _editedTranscription ??
                            audioState.realtimeTranscription ??
                            recordState.transcription ??
                            '';
                        NVCConfirmationModal.show(
                          context: context,
                          initialAnalysis: recordState.nvcAnalysis!,
                          transcription: transcription,
                          onRevert: () {
                            _handleProcessingModeSelected(
                                ProcessingMode.onlyRecord);
                          },
                        ).then((result) {
                          if (result?.action == NVCModalAction.confirm &&
                              result?.analysis != null &&
                              _completedAudioPath != null) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                AppColors.bgPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(_l10n.homeSavingRecord),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            recordBloc.add(
                              RecordCreateQuickNote(
                                audioPath: _completedAudioPath!,
                                mode: ProcessingMode.withNVC,
                                transcription: transcription,
                                nvcAnalysis: result!.analysis,
                                createdAt: result.selectedDateTime,
                              ),
                            );
                            _clearCompletedAudio();
                          } else if (result?.action == NVCModalAction.delete) {
                            // 用户选择了删除，清理音频文件
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.cancel_outlined,
                                        color: AppColors.textSecondary,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Text(_l10n.homeSaveCancelled),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            _clearCompletedAudio();
                          }
                        });
                      }
                    });
                  }

                  // 处理AI授权请求
                  if (recordState.status == RecordStatus.needsAIAuth) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // 先关闭分析加载动画弹窗
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      if (ModalRoute.of(context)?.isCurrent ?? false) {
                        _handleAIAuthRequest(context, recordState);
                      }
                    });
                  }

                  if (recordState.hasTranscriptionError &&
                      recordState.transcriptionErrorMessage != null &&
                      _completedAudioPath != null &&
                      recordState.transcriptionErrorMessage !=
                          _lastHandledTranscriptionError) {
                    _lastHandledTranscriptionError =
                        recordState.transcriptionErrorMessage;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFEF5350), size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child:
                                  Text(recordState.transcriptionErrorMessage!),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }

                  // 处理NVC分析错误
                  // 添加防重复机制：只在有新错误且弹窗未显示时触发
                  if (recordState.hasError &&
                      recordState.errorMessage != null &&
                      _completedAudioPath != null &&
                      !_isShowingErrorDialog &&
                      recordState.errorMessage != _lastHandledError) {
                    _isShowingErrorDialog = true;
                    _lastHandledError = recordState.errorMessage;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // 先关闭分析加载动画弹窗
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      if (ModalRoute.of(context)?.isCurrent ?? false) {
                        final transcription = recordState.transcription;
                        NVCErrorDialog.show(context: context).then((action) {
                          _isShowingErrorDialog = false;
                          if (action == NVCErrorAction.retry) {
                            // 清除错误记录，允许重试失败后再次显示错误
                            _lastHandledError = null;
                            // 立即重试NVC分析
                            if (transcription != null &&
                                transcription.isNotEmpty) {
                              if (!context.mounted) return;
                              context
                                  .read<RecordBloc>()
                                  .add(RecordAnalyzeNVC(transcription));
                            }
                          } else if (action == NVCErrorAction.saveText) {
                            // 保存为仅文本记录
                            _handleProcessingModeSelected(
                                ProcessingMode.onlyRecord);
                          }
                        });
                      } else {
                        _isShowingErrorDialog = false;
                      }
                    });
                  }

                  if (recordState.isSuccess &&
                      recordState.latestRecord != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF4CAF50), size: 20),
                            const SizedBox(width: 8),
                            Text(_l10n.homeRecordSaved),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(context, greeting),
                      const SizedBox(height: 12),
                      _buildWeekStrip(now),
                      const SizedBox(height: 146),
                      _buildQuoteSection(),
                      const SizedBox(height: 52),
                      const Spacer(),
                      BlocBuilder<AudioBloc, AudioState>(
                        buildWhen: (prev, next) =>
                            prev.status != next.status ||
                            prev.duration != next.duration ||
                            prev.hasPermission != next.hasPermission ||
                            prev.isStreamingRecording !=
                                next.isStreamingRecording ||
                            prev.isWebSocketConnected !=
                                next.isWebSocketConnected,
                        builder: (context, audioState) {
                          return _buildRecordSection(context, audioState);
                        },
                      ),
                      const SizedBox(height: 144),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部信息栏
  Widget _buildHeader(BuildContext context, String greeting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              greeting,
              style: AppTypography.homeGreeting.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF353F49),
                height: 1.05,
                letterSpacing: -0.45,
                fontFamily: AppTypography.sansFamily,
                fontFamilyFallback: const ['PingFang SC', 'Roboto'],
              ),
            ),
          ),
          // Pro 按钮
          if (!getIt<ProSubscriptionService>().hasProFeatureAccess)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProPurchaseScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4B896), AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          // 设置按钮
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              child: Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.68),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4B896).withValues(alpha: 0.70),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(DateTime now) {
    final baseDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(7, (index) {
          final date = baseDate.add(Duration(days: index));
          final isToday = _isSameDay(date, now);

          return Expanded(
            child: Column(
              children: [
                Text(
                  _l10n.getWeekday(index + 1),
                  style: TextStyle(
                    fontSize: 12,
                    color: isToday
                        ? AppColors.accent
                        : const Color(0xFFA8978A),
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 33,
                  height: 33,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        isToday ? AppColors.accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    date.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 32 / 2,
                      color: isToday
                          ? Colors.white
                          : const Color(0xFF9A8778).withValues(alpha: 0.95),
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildRecordSection(BuildContext context, AudioState audioState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: 0.5,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.50),
              blurRadius: 4,
              spreadRadius: 0.2,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Container(
          height: 57,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFD4B896).withValues(alpha: 0.90),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7FA5BF).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openInputScreen(autoStartRecording: false),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _l10n.homeRecordPrompt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.transcriptionStatus.copyWith(
                          fontSize: 29 / 2,
                          color: AppColors.textSecondary.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 21,
                color: const Color(0xFFD4B896).withValues(alpha: 0.70),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: _l10n.homeStartVoiceRecord,
                hint: _l10n.homeOpenVoiceInputHint,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openInputScreen(autoStartRecording: true),
                    child: SizedBox(
                    width: 44,
                    height: 44,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final pulse = _pulseController.value;
                        final isRecording = audioState.isRecording;
                        final haloOpacity =
                            isRecording ? 0.18 - (pulse * 0.08) : 0.0;
                        final haloSize = 44 + (pulse * 6);

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isRecording)
                              Container(
                                width: haloSize,
                                height: haloSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent
                                      .withValues(alpha: haloOpacity),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isRecording
                                      ? const [
                                          Color(0xFFD98B68),
                                          Color(0xFFC96F4A),
                                        ]
                                      : const [
                                          Color(0xFFCDAA85),
                                          Color(0xFFC4A57B),
                                        ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isRecording
                                            ? const Color(0xFFC96F4A)
                                            : AppColors.accent)
                                        .withValues(
                                      alpha: isRecording ? 0.28 : 0.30,
                                    ),
                                    blurRadius: isRecording ? 16 : 14,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.34),
                                    blurRadius: 3,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteSection() {
    if (!_quotesLoaded) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 372),
          child: SizedBox(
            width: double.infinity,
            height: 216,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _switchToNextQuote,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFFFCF8F3).withValues(alpha: 0.52),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFEFBF6).withValues(alpha: 0.72),
                      const Color(0xFFF8F0E6).withValues(alpha: 0.56),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFBFA080).withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _quoteTransitionController,
                      builder: (context, child) {
                        return _buildLyricQuoteViewport();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBackgroundPalette {
  final List<Color> gradientColors;
  final List<double> gradientStops;
  final Color bottomFogColor;
  final double bottomFogMiddleAlpha;
  final Color ringColor;
  final double ringAlpha;
  final Color overlayColor;
  final double overlayAlpha;

  const _HomeBackgroundPalette({
    required this.gradientColors,
    required this.gradientStops,
    required this.bottomFogColor,
    required this.bottomFogMiddleAlpha,
    required this.ringColor,
    required this.ringAlpha,
    required this.overlayColor,
    required this.overlayAlpha,
  });

  static const defaultPalette = _HomeBackgroundPalette(
    gradientColors: [
      Color(0xFFFEFCF9), // 暖奶白 — 顶部
      Color(0xFFFAF5EE), // 轻暖米 — 中段（比原来浅很多）
      Color(0xFFF6EFE4), // 淡暖杏 — 底部（替代过饱和琥珀）
    ],
    gradientStops: [0.0, 0.55, 1.0],
    bottomFogColor: Color(0xFFF2EAE0),
    bottomFogMiddleAlpha: 0.50,
    ringColor: Color(0xFFCDAA85),
    ringAlpha: 0.14,
    overlayColor: Color(0xFFCDAA85),
    overlayAlpha: 0.03,
  );
}

/// 背景纹理：顶部同心圆 + 轻颗粒
class _SoftUITexturePainter extends CustomPainter {
  final Color ringColor;
  final Color overlayColor;

  _SoftUITexturePainter({
    required this.ringColor,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shortSide = math.min(size.width, size.height);

    // 多个分散的纹理组：半径经过人工控制，避免组与组交叉
    final clusters = <_RingCluster>[
      const _RingCluster(
        anchorX: 0.18,
        anchorY: 0.17,
        maxRadiusFactor: 0.30,
        minRadiusFactor: 0.14,
        rings: 5,
        color: Color(0xFFD4C0A8), // 暖沙，替代蓝灰
        alpha: 0.13,
        irregularity: 0.050,
        phase: 0.35,
      ),
      const _RingCluster(
        anchorX: 0.80,
        anchorY: 0.23,
        maxRadiusFactor: 0.28,
        minRadiusFactor: 0.13,
        rings: 5,
        color: Color(0xFFCCB99E), // 暖沙
        alpha: 0.12,
        irregularity: 0.047,
        phase: 1.12,
      ),
      const _RingCluster(
        anchorX: 0.14,
        anchorY: 0.53,
        maxRadiusFactor: 0.27,
        minRadiusFactor: 0.12,
        rings: 5,
        color: Color(0xFFD8C9B2), // 暖沙
        alpha: 0.11,
        irregularity: 0.048,
        phase: 2.10,
      ),
      const _RingCluster(
        anchorX: 0.84,
        anchorY: 0.60,
        maxRadiusFactor: 0.275,
        minRadiusFactor: 0.125,
        rings: 5,
        color: Color(0xFFCFC0A6), // 暖沙
        alpha: 0.12,
        irregularity: 0.049,
        phase: 2.76,
      ),
      const _RingCluster(
        anchorX: 0.50,
        anchorY: 0.84,
        maxRadiusFactor: 0.34,
        minRadiusFactor: 0.16,
        rings: 5,
        color: Color(0xFFD2BEA4), // 暖沙
        alpha: 0.10,
        irregularity: 0.052,
        phase: 3.42,
      ),
    ];

    for (final cluster in clusters) {
      final center =
          Offset(size.width * cluster.anchorX, size.height * cluster.anchorY);
      final maxRadius = shortSide * cluster.maxRadiusFactor;
      final minRadius = shortSide * cluster.minRadiusFactor;
      final spacing = cluster.rings > 1
          ? (maxRadius - minRadius) / (cluster.rings - 1)
          : 0.0;

      for (int i = 0; i < cluster.rings; i++) {
        final radius = minRadius + spacing * i;
        final progress = cluster.rings > 1 ? i / (cluster.rings - 1) : 0.0;
        final strokeWidth =
            (1.55 - progress * 0.50).clamp(0.96, 1.55).toDouble();
        final alpha = (cluster.alpha * (1.0 - progress * 0.35))
            .clamp(0.07, 0.25)
            .toDouble();

        final ringPath = _buildIrregularRingPath(
          center: center,
          radius: radius,
          irregularity: cluster.irregularity,
          phase: cluster.phase + i * 0.18,
        );

        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = cluster.color.withValues(alpha: alpha);
        canvas.drawPath(ringPath, ringPaint);

        // 微弱高光描边，增强可见性但保持柔和
        final highlightPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (strokeWidth * 0.64).clamp(0.54, 1.10).toDouble()
          ..color = Colors.white
              .withValues(alpha: (alpha * 0.70).clamp(0.035, 0.13).toDouble());
        canvas.drawPath(ringPath, highlightPaint);
      }
    }

    // 一层全页低对比柔光，避免纹理边缘感太“硬”
    final veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          overlayColor.withValues(alpha: 0.028),
          overlayColor.withValues(alpha: 0.006),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), veilPaint);
  }

  Path _buildIrregularRingPath({
    required Offset center,
    required double radius,
    required double irregularity,
    required double phase,
  }) {
    const segments = 88;
    final path = Path();

    for (int i = 0; i <= segments; i++) {
      final baseT = (i / segments) * math.pi * 2;
      final warpedT = baseT +
          math.sin(baseT * 1.75 + phase) * 0.10 +
          math.cos(baseT * 3.35 - phase * 0.65) * 0.05;

      final wobble1 = math.sin((warpedT * 1.90) + phase) * irregularity;
      final wobble2 =
          math.cos((warpedT * 4.90) - (phase * 1.30)) * irregularity * 0.72;
      final wobble3 =
          math.sin((warpedT * 8.60) + (phase * 0.88)) * irregularity * 0.42;
      final wobble4 =
          math.cos((warpedT * 12.40) - (phase * 0.45)) * irregularity * 0.20;
      final r = radius * (1.0 + wobble1 + wobble2 + wobble3);

      final x = center.dx + math.cos(warpedT) * (r + wobble4 * radius);
      final y = center.dy + math.sin(warpedT) * (r - wobble4 * radius * 0.65);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SoftUITexturePainter oldDelegate) {
    return oldDelegate.ringColor != ringColor ||
        oldDelegate.overlayColor != overlayColor;
  }
}

class _RingCluster {
  final double anchorX;
  final double anchorY;
  final double maxRadiusFactor;
  final double minRadiusFactor;
  final int rings;
  final Color color;
  final double alpha;
  final double irregularity;
  final double phase;

  const _RingCluster({
    required this.anchorX,
    required this.anchorY,
    required this.maxRadiusFactor,
    required this.minRadiusFactor,
    required this.rings,
    required this.color,
    required this.alpha,
    required this.irregularity,
    required this.phase,
  });
}
