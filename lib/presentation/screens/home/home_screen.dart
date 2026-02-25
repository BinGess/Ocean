import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
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
import '../../../core/di/injection.dart';
import '../../../core/services/ai_auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String? _completedAudioPath;
  final List<String> _rollingDescriptions = [
    '任何感受都可以被接纳',
    '让情绪流淌',
    '允许任何事发生',
    '先看见，再思考',
  ];
  late final PageController _descriptionController;
  Timer? _descriptionTimer;
  int _currentDescriptionIndex = 0;
  bool _isDescriptionPaused = false;
  final ScrollController _transcriptionScrollController = ScrollController();
  String? _lastTranscriptionText;

  // 本地按压状态 - 用于即时视觉反馈
  bool _isPressed = false;

  // 录音开始时间 - 用于最小录音时长检查
  DateTime? _recordingStartTime;
  // 最小录音时长（毫秒）- 防止误触
  static const int _minRecordingDurationMs = 800;

  // 按钮脉冲动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 防止错误弹窗重复显示
  bool _isShowingErrorDialog = false;
  // 记录上次处理的错误消息，避免重复处理同一个错误
  String? _lastHandledError;
  // 用户手动关闭的错误提示（避免一直显示）
  String? _lastDismissedError;
  // 忽略下一次完成回调（用于短录音取消）
  bool _ignoreNextCompletion = false;

  @override
  void initState() {
    super.initState();
    // 注：不在此处加载记录列表，避免与 RecordsScreen 冲突
    // RecordsScreen 会加载完整的记录列表
    // 如果在此处使用 limit:5 加载，会覆盖 RecordsScreen 的完整列表

    // 注：权限和预热已在 AppEntryPoint 开屏期间处理
    // 这里仅作为备用检查，确保权限状态正确
    _checkAndRequestPermission();

    // 初始页设为中间的大数值，方便无限滚动
    int initialPage = 1000;
    _currentDescriptionIndex = initialPage;
    _descriptionController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.18, // 缩小视口比例，让词条更紧凑
    );

    // 初始化脉冲动画控制器 - 强化膨胀效果
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),  // 稍微延长持续时间
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(  // 从1.15增加到1.25
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _descriptionTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      if (_isDescriptionPaused) return;
      _currentDescriptionIndex++;
      _descriptionController.animateToPage(
        _currentDescriptionIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseDescription() {
    _isDescriptionPaused = true;
  }

  void _resumeDescription() {
    _isDescriptionPaused = false;
  }

  /// 备用权限检查（已禁用，避免重复弹窗）
  /// 权限已在 AppEntryPoint 开屏期间请求
  /// 这里不再主动检查，避免触发重复的权限对话框
  void _checkAndRequestPermission() {
    // 不再调用 AudioCheckPermission，因为 record 包的 hasPermission()
    // 在首次调用时会触发系统权限弹窗
    // 权限请求已在 AppEntryPoint 中统一处理
  }

  /// 尝试停止录音（检查最小录音时长）
  void _tryStopRecording(BuildContext context) {
    // 获取当前最新状态（不使用 BlocBuilder 捕获的旧状态）
    final currentState = context.read<AudioBloc>().state;

    // 检查最小录音时长
    if (_recordingStartTime != null) {
      final elapsed = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      // 如果还未真正进入录音状态（连接中），直接取消
      if (!currentState.isRecording) {
        debugPrint('HomeScreen: 连接中已松开，取消录音');
        _recordingStartTime = null;
        _ignoreNextCompletion = true;
        _completedAudioPath = null;
        context.read<AudioBloc>().requestCancel();
        context.read<AudioBloc>().add(const AudioCancelRecording());
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
                SizedBox(width: 8),
                Text('录音太短，请重试'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      if (elapsed < _minRecordingDurationMs) {
        debugPrint('HomeScreen: 录音时长不足 ${_minRecordingDurationMs}ms (当前: ${elapsed}ms)，取消录音');
        // 时长不足，取消录音并提示用户
        _recordingStartTime = null;
        _ignoreNextCompletion = true;
        _completedAudioPath = null;
        context.read<AudioBloc>().requestCancel();
        context.read<AudioBloc>().add(const AudioCancelRecording());
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
                SizedBox(width: 8),
                Text('录音太短，请重试'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    if (!currentState.isRecording) {
      debugPrint('HomeScreen: 录音未开始或尚在连接，忽略停止请求');
      return;
    }

    debugPrint('HomeScreen: 停止录音');
    HapticFeedback.lightImpact();
    _recordingStartTime = null;

    if (currentState.isStreamingRecording) {
      context.read<AudioBloc>().add(const AudioFinalizeStreaming());
    } else {
      context.read<AudioBloc>().add(const AudioStopRecording());
    }
  }

  void _handleRecordComplete(String audioPath) {
    setState(() {
      _completedAudioPath = audioPath;
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
          _handleProcessingModeSelected(result.mode, editedTranscription: result.transcription);
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
        _handleProcessingModeSelected(result.mode, editedTranscription: result.transcription);
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
        if (!mounted) return;
        context.read<RecordBloc>().add(
              RecordAnalyzeNVC(state.transcription!),
            );
      }
    } else {
      // 用户拒绝授权
      if (!mounted) return;
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

  void _handleProcessingModeSelected(ProcessingMode mode, {String? editedTranscription}) async {
    if (_completedAudioPath == null) return;

    // 优先使用用户编辑后的转写文本，其次流式转写，最后RecordBloc的转写
    final audioState = context.read<AudioBloc>().state;
    final streamTranscription = audioState.realtimeTranscription;
    final recordTranscription = context.read<RecordBloc>().state.transcription;
    final transcription = editedTranscription ?? streamTranscription ?? recordTranscription;

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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAF6F1)),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAF6F1)),
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
        if (transcription == null || transcription.isEmpty || transcription == '正在转写中...') {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Row(
                 children: [
                   Icon(Icons.hourglass_empty, color: Color(0xFFFFB74D), size: 20),
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
    });
  }

  @override
  void dispose() {
    _descriptionTimer?.cancel();
    _descriptionController.dispose();
    _transcriptionScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekDay = weekDays[now.weekday - 1];
    final dateStr = '${now.month}月${now.day}日 星期$weekDay';

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
              Color(0xFFFAF6F1), // 浅米白
              Color(0xFFF5EBE0), // 米黄色
            ],
          ),
        ),
        child: Stack(
          children: [
            // 背景纹理层 - 强化质感
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.7,
                  child: CustomPaint(
                    painter: _NoiseTexturePainter(),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            // 额外的渐变叠加层 - 增加深度感
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.3),
                      radius: 1.2,
                      colors: [
                        const Color(0xFFF5EBE0).withValues(alpha: 0.0),
                        const Color(0xFFE8DED0).withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 轻微光晕层已移除（避免角落阴影感）
            // 主内容
            BlocListener<AudioBloc, AudioState>(
              listener: (context, audioState) {
              // 录音完成后处理
              if (audioState.isCompleted && audioState.audioPath != null) {
                if (_ignoreNextCompletion) {
                  _ignoreNextCompletion = false;
                  return;
                }
                const minSeconds = _minRecordingDurationMs / 1000.0;
                if (audioState.duration < minSeconds) {
                  return;
                }
                _handleRecordComplete(audioState.audioPath!);
              }

              // 显示错误
              if (audioState.hasError && audioState.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF5350), size: 20),
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
                if (recordState.isAnalyzed && recordState.nvcAnalysis != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // 先关闭分析加载动画弹窗
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }

                    if (ModalRoute.of(context)?.isCurrent ?? false) {
                      final messenger = ScaffoldMessenger.of(context);
                      final recordBloc = context.read<RecordBloc>();
                      // 优先使用流式转写文本,避免显示占位符
                      final audioState = context.read<AudioBloc>().state;
                      final transcription = audioState.realtimeTranscription ??
                                           recordState.transcription ?? '';
                      NVCConfirmationModal.show(
                        context: context,
                        initialAnalysis: recordState.nvcAnalysis!,
                        transcription: transcription,
                        onRevert: () {
                          _handleProcessingModeSelected(ProcessingMode.onlyRecord);
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
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAF6F1)),
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
                              transcription: recordState.transcription,
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
                                  Icon(Icons.cancel_outlined, color: Color(0xFFB0B0B0), size: 20),
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
                          if (transcription != null && transcription.isNotEmpty) {
                            context.read<RecordBloc>().add(RecordAnalyzeNVC(transcription));
                          }
                        } else if (action == NVCErrorAction.saveText) {
                          // 保存为仅文本记录
                          _handleProcessingModeSelected(ProcessingMode.onlyRecord);
                        }
                      });
                    } else {
                      _isShowingErrorDialog = false;
                    }
                  });
                }

                if (recordState.isSuccess && recordState.latestRecord != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
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
                    // 顶部信息栏
                    _buildHeader(context, dateStr, greeting),

                    // 文字滚动区域 - 优化布局,给文案更多空间
                    Expanded(
                      flex: 1,
                      child: _buildDescriptionSection(context),
                    ),

                    // 实时转写显示区域 - 固定高度,不会影响按钮位置
                    BlocBuilder<AudioBloc, AudioState>(
                      buildWhen: (prev, next) =>
                          prev.isStreamingRecording != next.isStreamingRecording ||
                          prev.isWebSocketConnected != next.isWebSocketConnected ||
                          prev.realtimeTranscription != next.realtimeTranscription ||
                          prev.isTranscriptionFinal != next.isTranscriptionFinal ||
                          prev.status != next.status,
                      builder: (context, audioState) {
                        return _buildTranscriptionArea(audioState);
                      },
                    ),

                    // 录音按钮区域 - 调整比例,保持整体平衡
                    Expanded(
                      flex: 1,
                      child: BlocBuilder<AudioBloc, AudioState>(
                        buildWhen: (prev, next) =>
                            prev.status != next.status ||
                            prev.duration != next.duration ||
                            prev.hasPermission != next.hasPermission ||
                            prev.isWebSocketConnected != next.isWebSocketConnected,
                        builder: (context, audioState) {
                          return _buildRecordSection(context, audioState);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // NVC分析时已使用NVCAnalyzingModal，不再需要LoadingOverlay
          ],
        ),
      ),
    );
  }

  /// 顶部信息栏
  Widget _buildHeader(BuildContext context, String dateStr, String greeting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧日期和问候
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB8ADA0),
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Color(0xFF5D4E3C),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // 右侧设置入口
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF8B7D6B),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSection(BuildContext context, AudioState audioState) {
    // 权限被拒绝
    if (!audioState.hasPermission &&
        audioState.status == RecordingStatus.permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mic_off,
              size: 56,
              color: Color(0xFFD9C9B8),
            ),
            const SizedBox(height: 16),
            const Text(
              '需要录音权限才能使用此功能',
              style: TextStyle(
                color: Color(0xFF8B7D6B),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.read<AudioBloc>().add(const AudioRequestPermission());
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE8DED0),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '授予权限',
                style: TextStyle(
                  color: Color(0xFF5D4E3C),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 合并状态：本地按压状态或实际录音状态
    final isActive = _isPressed || audioState.isRecording;
    final isConnecting = _isPressed &&
        !audioState.isRecording &&
        !audioState.isStreamingRecording;
    final isPressingOnly = _isPressed && !audioState.isRecording;
    final buttonSize = audioState.isRecording ? 106.0 : (_isPressed ? 102.0 : 120.0);
    final iconSize = audioState.isRecording ? 38.0 : (_isPressed ? 40.0 : 48.0);
    final ringAlpha = isPressingOnly ? 0.6 : (isActive ? 0.42 : 0.16);  // 增强透明度
    final ringWidth = isPressingOnly ? 2.6 : (isActive ? 2.0 : 1.4);  // 增加边框宽度
    final mainBorderWidth = isPressingOnly ? 3.1 : (isActive ? 2.8 : 2.4);  // 增加边框宽度
    final mainGlowAlpha = isPressingOnly ? 0.4 : (isActive ? 0.32 : 0.24);  // 增强发光
    final mainGlowBlur = isPressingOnly ? 32.0 : (isActive ? 28.0 : 16.0);  // 增大发光范围
    final mainGlowSpread = isPressingOnly ? 5.0 : (isActive ? 4.0 : 2.5);  // 增加发光范围

    // 控制脉冲动画
    if (audioState.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!audioState.isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // 正常录音界面
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 提示文字
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                audioState.isRecording
                    ? '松开结束'
                    : (isConnecting ? '连接中...' : '按住记录'),
                key: ValueKey(audioState.isRecording),
                style: TextStyle(
                  fontSize: 14,
                  color: isActive
                      ? const Color(0xFF5D4E3C)
                      : const Color(0xFFB8ADA0),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 录音按钮 - 只允许长按操作，屏蔽快速点击
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 快速点击不触发录音，只有长按才开始录音
              onLongPressStart: (_) {
                // 长按开始：设置视觉反馈并开始录音
                setState(() => _isPressed = true);
                _ignoreNextCompletion = false;
                _pauseDescription();
                HapticFeedback.lightImpact();
                _recordingStartTime = DateTime.now();
                // 触发录音
                if (!audioState.isRecording) {
                  context.read<AudioBloc>().add(const AudioStartStreamingRecording());
                }
              },
              onLongPressEnd: (_) {
                // 长按结束：停止录音
                setState(() => _isPressed = false);
                _resumeDescription();
                _tryStopRecording(context);
              },
              onLongPressCancel: () {
                // 长按取消（手指滑出）：保持录音继续，只重置视觉状态
                setState(() => _isPressed = false);
                _resumeDescription();
              },
            child: SizedBox(
              width: 160,
              height: 160,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 水波纹效果（独立Widget，自行管理动画）
                    _RippleEffect(isActive: isActive),

                    // 外圈脉冲效果（录音时） - 强化版
                    if (audioState.isRecording)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final pulseColor = isConnecting
                              ? const Color(0xFF7DBEF5)
                              : const Color(0xFFC4A57B);
                          // 调整 alpha 计算，适配新的动画范围 1.0-1.25
                          final alphaFactor = (1.25 - _pulseAnimation.value) / 0.25;
                          return Container(
                            width: 120 * _pulseAnimation.value,
                            height: 120 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: pulseColor.withValues(
                                  alpha: 0.5 * alphaFactor,  // 从0.4增加到0.5
                                ),
                                width: 2.5,  // 从2增加到2.5
                              ),
                            ),
                          );
                        },
                      ),

                    // 按住时柔和外环，增强触达反馈
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: isActive ? buttonSize + 20 : buttonSize + 6,
                      height: isActive ? buttonSize + 20 : buttonSize + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isConnecting
                                  ? const Color(0xFF9ECDF4)
                                  : const Color(0xFFD9C9B8))
                              .withValues(alpha: ringAlpha),
                          width: ringWidth,
                        ),
                      ),
                    ),

                    // 主按钮
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isConnecting
                                ? const Color(0xFFF2F7FF)
                                : (audioState.isRecording
                                    ? const Color(0xFFFFF7EE)
                                    : Colors.white))
                            .withValues(alpha: isActive ? 0.97 : 0.93),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFC4A57B)
                              : const Color(0xFFD9C9B8),
                          width: mainBorderWidth,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFC4A57B).withValues(alpha: mainGlowAlpha),
                                  blurRadius: mainGlowBlur,
                                  spreadRadius: mainGlowSpread,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(0xFFD9C9B8).withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  spreadRadius: 2.0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          audioState.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          key: ValueKey(audioState.isRecording),
                          size: iconSize,
                          color: isActive
                              ? const Color(0xFFC4A57B)
                              : const Color(0xFFD9C9B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 录音时长显示
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: audioState.isRecording && audioState.duration > 0 ? 40 : 0,
            child: audioState.isRecording && audioState.duration > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _formatDuration(audioState.duration),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8B7D6B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      ),
    );
  }

  /// 构建实时转写区域 - 固定高度,不影响按钮位置
  Widget _buildTranscriptionArea(AudioState audioState) {
    // 判断是否应该显示转写区域：
    // 1. 正在流式录音时显示
    // 2. 或者正在按压按钮且正在连接中时显示（提供即时反馈）
    final isConnecting = _isPressed && !audioState.isStreamingRecording && !audioState.isRecording;
    final shouldShow = audioState.isStreamingRecording || isConnecting;

    // 固定高度容器,保持布局稳定,优化动画性能
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,  // 使用更流畅的动画曲线
      height: shouldShow
          ? 140  // 转写框显示时的高度（减小以避免溢出）
          : 8,   // 收起时的最小高度
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: shouldShow
          ? _buildRealtimeTranscription(audioState, isConnecting: isConnecting)
          : const SizedBox.shrink(),
    );
  }

  String _formatDuration(double seconds) {
    final totalSeconds = seconds.floor();
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 构建实时转写显示widget
  Widget _buildRealtimeTranscription(AudioState audioState, {bool isConnecting = false}) {
    // 确定状态文本和颜色
    String statusText;
    Color statusColor;
    if (isConnecting) {
      statusText = '连接中...';
      statusColor = const Color(0xFF2196F3); // 蓝色：连接中
    } else if (audioState.isWebSocketConnected) {
      statusText = '实时识别中';
      statusColor = const Color(0xFF4CAF50); // 绿色：已连接
    } else {
      statusText = '离线录音中';
      statusColor = const Color(0xFFFF9800); // 橙色：离线
    }

    final transcription = audioState.realtimeTranscription?.trim();
    final isEmptyText = transcription == null || transcription.isEmpty;

    if (!isConnecting && !isEmptyText && transcription != _lastTranscriptionText) {
      _lastTranscriptionText = transcription;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_transcriptionScrollController.hasClients) return;
        _transcriptionScrollController.animateTo(
          _transcriptionScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      });
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 130),  // 进一步减少最大高度
      padding: const EdgeInsets.all(12),  // 减少内边距,优化空间利用
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),  // 稍微减小圆角
        border: Border.all(
          color: const Color(0xFFE8DED0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),  // 柔化阴影
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态指示器
          Row(
            children: [
              // 连接状态点（连接中时显示动画）
              if (isConnecting)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B7D6B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 转写文本
          Flexible(
            child: SingleChildScrollView(
              controller: _transcriptionScrollController,
              child: isConnecting
                  ? const Text(
                      '正在准备录音...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8B7D6B),
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : (isEmptyText
                      ? _buildTranscriptionSkeleton()
                      : Text(
                          transcription,
                          style: TextStyle(
                            fontSize: 16,
                            color: audioState.isTranscriptionFinal
                                ? const Color(0xFF2C2C2C) // 黑色：最终结果
                                : const Color(0xFF8B7D6B), // 灰色：临时结果
                            fontStyle: audioState.isTranscriptionFinal
                                ? FontStyle.normal
                                : FontStyle.italic,
                            height: 1.6,
                            fontWeight: audioState.isTranscriptionFinal
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonLine(widthFactor: 0.9),
        const SizedBox(height: 8),
        _skeletonLine(widthFactor: 0.7),
        const SizedBox(height: 8),
        _skeletonLine(widthFactor: 0.5),
      ],
    );
  }

  Widget _skeletonLine({required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFFEFE6DA),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),  // 增加上下内边距
      child: PageView.builder(
        controller: _descriptionController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final textIndex = index % _rollingDescriptions.length;
          return AnimatedBuilder(
            animation: _descriptionController,
            builder: (context, child) {
              double page = 0;
              try {
                if (_descriptionController.position.haveDimensions) {
                  page = _descriptionController.page ?? _currentDescriptionIndex.toDouble();
                } else {
                  page = _currentDescriptionIndex.toDouble();
                }
              } catch (_) {
                page = _currentDescriptionIndex.toDouble();
              }

              double distance = (page - index).abs();

            // 根据距离计算样式（糯米色主题）
            double scale = 0.8;
            double opacity = 0.2;
            Color color = const Color(0xFFD4C4B0); // 浅褐色
            FontWeight fontWeight = FontWeight.normal;
            double fontSize = 18;

            if (distance < 0.5) {
               // 当前中心项
               scale = 1.0;
               opacity = 1.0;
               color = const Color(0xFF5D4E3C); // 深褐色
               fontWeight = FontWeight.w600;
               fontSize = 26;
            } else if (distance < 1.5) {
               // 相邻项
               double factor = 1.0 - (distance - 0.5);
               scale = 0.8 + (0.2 * factor);
               opacity = 0.2 + (0.8 * factor);
               color = Color.lerp(
                 const Color(0xFFD4C4B0),
                 const Color(0xFF5D4E3C),
                 factor,
               )!;
               fontSize = 18 + (8 * factor);
               if (factor > 0.5) fontWeight = FontWeight.w500;
            }

            return Center(
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      _rollingDescriptions[textIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        height: 1.5,  // 增加行高,优化可读性
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      ),
    );
  }
}

/// 水波纹动画效果 - 独立 Widget，自行管理动画生命周期
/// 解决在 BlocBuilder 内部动画无法正确启动的问题
class _RippleEffect extends StatefulWidget {
  final bool isActive;

  const _RippleEffect({required this.isActive});

  @override
  State<_RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<_RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const Duration _slowDuration = Duration(milliseconds: 4200);
  static const Duration _fastDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.isActive ? _fastDuration : _slowDuration,
    )..repeat(); // 立即开始循环动画
  }

  @override
  void didUpdateWidget(_RippleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _controller.duration = widget.isActive ? _fastDuration : _slowDuration;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (index) {
            final phaseOffset = index / 3.0;
            final progress = (_controller.value + phaseOffset) % 1.0;

            // 波纹从按钮边缘向外扩展 - 强化效果
            final minSize = widget.isActive ? 126.0 : 118.0;
            final maxSize = widget.isActive ? 200.0 : 260.0;  // 增加最大尺寸
            final size = minSize + (maxSize - minSize) * progress;

            // 透明度：更强的初始值，更缓的衰减 - 增强视觉效果
            final baseAlpha = widget.isActive ? 0.62 : 0.42;  // 大幅提高初始透明度
            // 使用更温和的衰减曲线，使波纹更可见
            final fadeFactor = widget.isActive
                ? math.pow(1.0 - progress, 1.6).toDouble()  // 从2.0改为1.6，衰减更缓
                : math.pow(1.0 - progress, 1.8).toDouble();  // 从2.2改为1.8，衰减更缓
            final alpha = (baseAlpha * fadeFactor).clamp(0.0, 1.0);

            // 边框宽度渐变 - 增强边框
            final borderWidth = widget.isActive
                ? 2.4 - progress * 1.0  // 从2.0改为2.4
                : 2.0 - progress * 0.8;  // 从1.6改为2.0

            // 颜色
            final color = widget.isActive
                ? const Color(0xFFC4A57B)
                : const Color(0xFFD4BAA6);  // 更明显的色彩

            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: alpha),
                  width: borderWidth.clamp(0.8, 3.0),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 细腻噪点纹理 - 强化版（多层纹理叠加）
class _NoiseTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 第一层：密集细小点纹理 - 形成基础噪点感
    final tinyPointPaint = Paint()
      ..color = const Color(0xFFB5A597).withValues(alpha: 0.18)
      ..strokeWidth = 0;
    const tinyStep = 6.0;
    for (double y = 0; y < size.height; y += tinyStep) {
      for (double x = 0; x < size.width; x += tinyStep) {
        final offsetX = (y * 0.7) % tinyStep;
        canvas.drawCircle(Offset(x + offsetX, y), 0.4, tinyPointPaint);
      }
    }

    // 第二层：中等点纹理 - 增加层次
    final mediumPointPaint = Paint()
      ..color = const Color(0xFFA89480).withValues(alpha: 0.14)
      ..strokeWidth = 0;
    const mediumStep = 14.0;
    for (double y = 0; y < size.height; y += mediumStep) {
      for (double x = 0; x < size.width; x += mediumStep) {
        final offsetX = (y * 0.5) % mediumStep;
        canvas.drawCircle(Offset(x + offsetX, y), 0.7, mediumPointPaint);
      }
    }

    // 第三层：稀疏大点纹理 - 增加深度
    final largePointPaint = Paint()
      ..color = const Color(0xFF9A8672).withValues(alpha: 0.10)
      ..strokeWidth = 0;
    const largeStep = 28.0;
    for (double y = 0; y < size.height; y += largeStep) {
      for (double x = 0; x < size.width; x += largeStep) {
        final offsetX = (y * 0.3) % largeStep;
        canvas.drawCircle(Offset(x + offsetX, y), 1.2, largePointPaint);
      }
    }

    // 第四层：细微横向纤维纹理 - 模拟纸张质感
    final fiberPaint = Paint()
      ..color = const Color(0xFFCBBBA8).withValues(alpha: 0.06)
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round;
    const fiberStep = 20.0;
    for (double y = 0; y < size.height; y += fiberStep) {
      final startX = (y * 1.3) % 30;
      final lineLength = 15.0 + (y % 20);
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + lineLength, y + 0.5),
        fiberPaint,
      );
    }

    // 第五层：斜向细纹 - 增加有机感
    final diagonalPaint = Paint()
      ..color = const Color(0xFFD4C4B0).withValues(alpha: 0.05)
      ..strokeWidth = 0.3
      ..strokeCap = StrokeCap.round;
    const diagonalStep = 35.0;
    for (double y = 0; y < size.height + size.width; y += diagonalStep) {
      final startY = y < size.width ? 0.0 : y - size.width;
      final startX = y < size.width ? size.width - y : 0.0;
      final endY = startY + 12;
      final endX = startX + 12;
      if (startX < size.width && startY < size.height) {
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX.clamp(0, size.width), endY.clamp(0, size.height)),
          diagonalPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
