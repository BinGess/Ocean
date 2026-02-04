import 'dart:async';
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
import '../../widgets/loading_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String? _completedAudioPath;
  final List<String> _rollingDescriptions = [
    '任何感受可以被接纳',
    '让情绪流淌',
    '允许任何事发生',
    '先看见，再思考',
  ];
  late final PageController _descriptionController;
  Timer? _descriptionTimer;
  int _currentDescriptionIndex = 0;
  bool _isDescriptionPaused = false;

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

  @override
  void initState() {
    super.initState();
    // 加载最近的记录
    context.read<RecordBloc>().add(const RecordLoadList(limit: 5));

    // 主动检查并请求录音权限（避免在按下录音按钮时才弹出权限对话框）
    _checkAndRequestPermission();
    // 预热录音资源，降低首次录音卡顿
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<AudioBloc>().add(const AudioWarmUp());
    });

    // 初始页设为中间的大数值，方便无限滚动
    int initialPage = 1000;
    _currentDescriptionIndex = initialPage;
    _descriptionController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.18, // 缩小视口比例，让词条更紧凑
    );

    // 初始化脉冲动画控制器
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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

  /// 检查并请求录音权限
  /// 在页面初始化时调用，避免用户按下录音按钮时才弹出权限对话框
  void _checkAndRequestPermission() {
    final audioBloc = context.read<AudioBloc>();
    final audioState = audioBloc.state;

    // 如果还没有权限，先检查权限状态
    if (!audioState.hasPermission) {
      // 延迟一小段时间再请求，让页面先完成渲染
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        // 直接请求权限（会触发系统权限对话框）
        context.read<AudioBloc>().add(const AudioRequestPermission());
      });
    }
  }

  /// 尝试停止录音（检查最小录音时长）
  void _tryStopRecording(BuildContext context) {
    // 获取当前最新状态（不使用 BlocBuilder 捕获的旧状态）
    final currentState = context.read<AudioBloc>().state;

    if (!currentState.isRecording) {
      debugPrint('HomeScreen: 录音未开始，忽略停止请求');
      return;
    }

    // 检查最小录音时长
    if (_recordingStartTime != null) {
      final elapsed = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      if (elapsed < _minRecordingDurationMs) {
        debugPrint('HomeScreen: 录音时长不足 ${_minRecordingDurationMs}ms (当前: ${elapsed}ms)，继续录音');
        // 时长不足，不停止录音，让用户继续录音
        // 用户需要再次点击才能停止
        return;
      }
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

    // 如果有流式转写结果，直接使用；否则触发传统转写
    if (streamTranscription != null && streamTranscription.isNotEmpty) {
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
          SnackBar(
            content: const Row(
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
              content: const Row(
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
        if (transcription == null || transcription.isEmpty || transcription == '正在转写中...') {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Row(
                 children: [
                   Icon(Icons.hourglass_empty, color: Color(0xFFFFB74D), size: 20),
                   SizedBox(width: 8),
                   Text('转写未完成，请稍后...'),
                 ],
               ),
               duration: const Duration(seconds: 2),
             ),
           );
           return;
        }

        // 触发 NVC 分析，分析完成后会在 BlocListener 中处理
        if (transcription != null && transcription.isNotEmpty) {
           context.read<RecordBloc>().add(RecordAnalyzeNVC(transcription));
           // 注意：这里不要立即清除 _completedAudioPath，因为后续保存还需要它
        } else {
           // 如果没有转写文本，无法分析，降级为直接保存
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Row(
                 children: [
                   Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
                   SizedBox(width: 8),
                   Flexible(child: Text('暂无转写文本，已自动转为仅记录')),
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
    });
  }

  @override
  void dispose() {
    _descriptionTimer?.cancel();
    _descriptionController.dispose();
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
            // 背景纹理层
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.35,
                  child: CustomPaint(
                    painter: _NoiseTexturePainter(),
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
                            SnackBar(
                              content: const Row(
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
                              duration: const Duration(seconds: 2),
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
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.cancel_outlined, color: Color(0xFFB0B0B0), size: 20),
                                  SizedBox(width: 8),
                                  Text('已取消保存'),
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
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                          SizedBox(width: 8),
                          Text('记录已保存'),
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

          // 加载遮罩
          BlocBuilder<RecordBloc, RecordState>(
            builder: (context, state) {
              String? message;
              // 仅在 NVC 分析时显示全屏遮罩，因为分析需要用户确认后续步骤
              if (state.isAnalyzing) {
                message = '正在分析...';
              }
              // 注意：isCreating (保存中) 不再显示全屏遮罩，改为后台执行 + SnackBar 提示
              // 这样即使用户网络慢，也不会感觉界面死机

              return LoadingOverlay(
                isLoading: state.isAnalyzing,
                message: message,
              );
            },
          ),
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

          // 右侧用户图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD9C9B8),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF8B7D6B),
              size: 24,
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

                    // 外圈脉冲效果（录音时）
                    if (audioState.isRecording)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final pulseColor = isConnecting
                              ? const Color(0xFF7DBEF5)
                              : const Color(0xFFC4A57B);
                          return Container(
                            width: 120 * _pulseAnimation.value,
                            height: 120 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: pulseColor.withValues(
                                  alpha: 0.4 * (1.15 - _pulseAnimation.value) / 0.15,
                                ),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),

                    // 主按钮
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 100 : 120,
                      height: isActive ? 100 : 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isConnecting
                                ? const Color(0xFFF2F7FF)
                                : (audioState.isRecording
                                    ? const Color(0xFFFFF7EE)
                                    : Colors.white))
                            .withValues(alpha: isActive ? 0.96 : 0.92),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFC4A57B)
                              : const Color(0xFFD9C9B8),
                          width: isActive ? 3 : 2.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFC4A57B).withValues(alpha: 0.28),
                                  blurRadius: 26,
                                  spreadRadius: 5,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(0xFFD9C9B8).withValues(alpha: 0.22),
                                  blurRadius: 14,
                                  spreadRadius: 2.5,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          audioState.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          key: ValueKey(audioState.isRecording),
                          size: isActive ? 40 : 48,
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
                          transcription!,
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

  static const Duration _slowDuration = Duration(milliseconds: 2200);
  static const Duration _fastDuration = Duration(milliseconds: 1000);

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

            // 波纹从按钮边缘向外扩展
            final minSize = widget.isActive ? 125.0 : 122.0;
            final maxSize = widget.isActive ? 160.0 : 155.0;
            final size = minSize + (maxSize - minSize) * progress;

            // 透明度：非线性衰减，中段更明显
            final baseAlpha = widget.isActive ? 0.55 : 0.4;
            final fade = (1.0 - progress) * (0.3 + 0.7 * (1.0 - progress));
            final alpha = baseAlpha * fade;

            // 边框宽度渐变
            final borderWidth = widget.isActive
                ? 2.5 - progress * 1.5
                : 2.0 - progress * 1.0;

            // 颜色
            final color = widget.isActive
                ? const Color(0xFFC4A57B)
                : const Color(0xFFCDBBA8);

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

/// 细腻噪点纹理（轻微）
class _NoiseTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFAF9C).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    // 简单规则网格点，避免引入随机数导致抖动
    const step = 18.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x + (y % (step * 0.6)), y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
