import 'dart:async';
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
import 'emotion_input_screen.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';
import '../../../core/services/quote_preloader.dart';
import '../../../core/theme/app_typography.dart';

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
  bool _isQuoteFadingOut = true;
  late AnimationController _quoteTransitionController;

  // 按钮脉冲动画控制器
  late AnimationController _pulseController;

  // 防止错误弹窗重复显示
  bool _isShowingErrorDialog = false;
  // 记录上次处理的错误消息，避免重复处理同一个错误
  String? _lastHandledError;

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
      duration: const Duration(milliseconds: 320),
    );
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
    _isQuoteFadingOut = true;
    await _quoteTransitionController.forward(from: 0);
    if (!mounted) {
      _isQuoteSwitching = false;
      return;
    }
    setState(() {
      _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
    });
    _isQuoteFadingOut = false;
    await _quoteTransitionController.reverse(from: 1);
    _isQuoteSwitching = false;
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

    // 获取AudioState以检查是否有流式转写结果
    final audioState = context.read<AudioBloc>().state;
    final streamTranscription = audioState.realtimeTranscription;

    // 如果流式转写结果为空，说明可能没有实际内容输入，取消录音
    if (streamTranscription == null || streamTranscription.trim().isEmpty) {
      debugPrint('HomeScreen: 转写结果为空，取消录音');
      _completedAudioPath = null;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
              SizedBox(width: 8),
              Text('内容太短，请重试'),
            ],
          ),
          duration: Duration(seconds: 2),
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
                transcription: state.transcription ?? '正在转写中...',
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
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFFAF6F1)),
                  ),
                ),
                SizedBox(width: 10),
                Text('正在保存记录...'),
              ],
            ),
            duration: Duration(seconds: 2),
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
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFAF6F1)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('正在保存记录...'),
                ],
              ),
              duration: Duration(seconds: 2),
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
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      color: Color(0xFFFFB74D), size: 20),
                  SizedBox(width: 8),
                  Text('转写未完成，请稍后...'),
                ],
              ),
              duration: Duration(seconds: 2),
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
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
                  SizedBox(width: 8),
                  Flexible(child: Text('暂无转写文本，已自动转为仅记录')),
                ],
              ),
              duration: Duration(seconds: 3),
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

    String greeting = '晚上好';
    final hour = now.hour;
    if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 18) {
      greeting = '下午好';
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD3E4EE),
              Color(0xFFD1E1EB),
              Color(0xFFD6E2E8),
            ],
            stops: [0.0, 0.62, 1.0],
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
                  painter: _SoftUITexturePainter(),
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
                        const Color(0xFFE9E6E1).withValues(alpha: 0.0),
                        const Color(0xFFE9E6E1).withValues(alpha: 0.64),
                        const Color(0xFFE8E4DF),
                      ],
                      stops: const [0.0, 0.56, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            BlocListener<AudioBloc, AudioState>(
              listener: (context, audioState) {
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
                              const SnackBar(
                                content: Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFFFAF6F1)),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('正在保存记录...'),
                                  ],
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            recordBloc.add(
                              RecordCreateQuickNote(
                                audioPath: _completedAudioPath!,
                                mode: ProcessingMode.withNVC,
                                transcription: transcription,
                                nvcAnalysis: result!.analysis,
                              ),
                            );
                            _clearCompletedAudio();
                          } else if (result?.action == NVCModalAction.delete) {
                            // 用户选择了删除，清理音频文件
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.cancel_outlined,
                                        color: Color(0xFFB0B0B0), size: 20),
                                    SizedBox(width: 8),
                                    Text('已取消保存'),
                                  ],
                                ),
                                duration: Duration(seconds: 2),
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
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Color(0xFF4CAF50), size: 20),
                            SizedBox(width: 8),
                            Text('记录已保存'),
                          ],
                        ),
                        duration: Duration(seconds: 2),
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
                fontSize: 44,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF353F49),
                height: 1.05,
                letterSpacing: -0.45,
                fontFamily: AppTypography.sansFamily,
                fontFamilyFallback: const ['PingFang SC', 'Roboto'],
              ),
            ),
          ),
          GestureDetector(
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
                  color: const Color(0xFF9CBBD0).withValues(alpha: 0.88),
                  width: 1.0,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF7190A5),
                  size: 21,
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
    const labels = ['一', '二', '三', '四', '五', '六', '日'];

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
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: isToday
                        ? const Color(0xFF6B9FC2)
                        : const Color(0xFF8397A7),
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
                        isToday ? const Color(0xFF63A2C9) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    date.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 32 / 2,
                      color: isToday
                          ? Colors.white
                          : const Color(0xFF6D8497).withValues(alpha: 0.95),
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
              color: const Color(0xFF5FAED8).withValues(alpha: 0.22),
              blurRadius: 16,
              spreadRadius: 0.8,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
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
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF5FAED8).withValues(alpha: 0.98),
              width: 1.55,
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openInputScreen(autoStartRecording: false),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '记录下此刻的情绪',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.transcriptionStatus.copyWith(
                        fontSize: 29 / 2,
                        color: const Color(0xFFC1CBD3),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 21,
                color: const Color(0xFFCBD5DE).withValues(alpha: 0.95),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openInputScreen(autoStartRecording: true),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(
                    Icons.mic_none_rounded,
                    size: 19,
                    color: Color(0xFF95A8B8),
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

    final quoteText = _quotes.isEmpty
        ? '观察当下，不做评判，这就是冥想的开始'
        : _quotes[_currentQuoteIndex % _quotes.length].content;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 372),
          child: SizedBox(
            width: double.infinity,
            height: 168,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _switchToNextQuote,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFFF5F7FA).withValues(alpha: 0.66),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF7F9FC),
                      Color(0xFFF2F5F8),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.68),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7A9CB4).withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      '一起来想想：',
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionSubtle.copyWith(
                        color: const Color(0xFFAFB8C1),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 86,
                      child: AnimatedBuilder(
                        animation: _quoteTransitionController,
                        builder: (context, child) {
                          final progress = _quoteTransitionController.value;
                          final opacity = (1 - progress).clamp(0.0, 1.0);
                          final slideY = _isQuoteFadingOut
                              ? -(progress * 0.05)
                              : (progress * 0.05);
                          final scale = _isQuoteFadingOut
                              ? 1 + (progress * 0.016)
                              : 0.984 + ((1 - progress) * 0.016);

                          return Transform.translate(
                            offset: Offset(0, slideY * 24),
                            child: Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: opacity,
                                child: Text(
                                  quoteText,
                                  key: ValueKey(
                                      'quote-$_currentQuoteIndex-$quoteText'),
                                  textAlign: TextAlign.center,
                                  style:
                                      AppTypography.transcriptionBody.copyWith(
                                    fontSize: 38 / 2,
                                    height: 1.48,
                                    color: const Color(0xFF2D3A46),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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

/// 背景纹理：顶部同心圆 + 轻颗粒
class _SoftUITexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.155);

    final ringPaint = Paint()
      ..color = const Color(0xFF9CBBCD).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    final ringHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(center, 68 + (i * 52), ringPaint);
      canvas.drawCircle(center, 68 + (i * 52) - 1.2, ringHighlightPaint);
    }

    final softOverlay = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.1,
        colors: [
          const Color(0xFFB0C7D6).withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.55));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.55), softOverlay);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
