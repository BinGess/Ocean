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

  // 本地按压状态 - 用于即时视觉反馈
  bool _isPressed = false;

  // 按钮脉冲动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> a782766 (fix: 修复NVC分析时错误弹窗误触发的问题)
  // 防止错误弹窗重复显示
  bool _isShowingErrorDialog = false;
  // 记录上次处理的错误消息，避免重复处理同一个错误
  String? _lastHandledError;

<<<<<<< HEAD
=======
>>>>>>> 652bbbe (feat: 优化录制按钮的即时响应和交互体验)
=======
>>>>>>> a782766 (fix: 修复NVC分析时错误弹窗误触发的问题)
  @override
  void initState() {
    super.initState();
    // 加载最近的记录
    context.read<RecordBloc>().add(const RecordLoadList(limit: 5));
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

    _descriptionTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _currentDescriptionIndex++;
      _descriptionController.animateToPage(
        _currentDescriptionIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
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
      showModalBottomSheet<ProcessingMode>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (context) {
          return BlocBuilder<RecordBloc, RecordState>(
            builder: (context, state) {
              return ProcessingChoiceModal(
                transcription: state.transcription ?? '正在转写中...',
                onSelect: (mode) => Navigator.of(context).pop(mode),
                onCancel: () => Navigator.of(context).pop(),
              );
            },
          );
        },
      ).then((mode) {
        if (mode != null && _completedAudioPath != null) {
          _handleProcessingModeSelected(mode);
        }
      });
    }
  }

  /// 显示处理选择模态框
  void _showProcessingChoice(String transcription) {
    showModalBottomSheet<ProcessingMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) {
        return ProcessingChoiceModal(
          transcription: transcription,
          onSelect: (mode) => Navigator.of(context).pop(mode),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    ).then((mode) {
      if (mode != null && _completedAudioPath != null) {
        _handleProcessingModeSelected(mode);
      }
    });
  }

  void _handleProcessingModeSelected(ProcessingMode mode) async {
    if (_completedAudioPath == null) return;

    // 优先使用流式转写文本，如果没有则使用RecordBloc的转写文本
    final audioState = context.read<AudioBloc>().state;
    final streamTranscription = audioState.realtimeTranscription;
    final recordTranscription = context.read<RecordBloc>().state.transcription;
    final transcription = streamTranscription ?? recordTranscription;

    switch (mode) {
      case ProcessingMode.onlyRecord:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在后台保存记录...')),
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
            const SnackBar(content: Text('正在后台保存记录...')),
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
             const SnackBar(content: Text('转写未完成，请稍后...')),
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
             const SnackBar(content: Text('暂无转写文本，无法进行 NVC 分析，已自动转为仅记录')),
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
                  SnackBar(content: Text(audioState.errorMessage!)),
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
                            const SnackBar(content: Text('正在后台保存记录...')),
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
                            const SnackBar(content: Text('已取消保存')),
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
                    const SnackBar(content: Text('记录已保存')),
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
                      builder: (context, audioState) {
                        return _buildTranscriptionArea(audioState);
                      },
                    ),

                    // 录音按钮区域 - 调整比例,保持整体平衡
                    Expanded(
                      flex: 1,
                      child: BlocBuilder<AudioBloc, AudioState>(
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

    // 控制脉冲动画
    if (audioState.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!audioState.isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // 正常录音界面
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示文字
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              audioState.isRecording ? '松开结束' : '按住记录',
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
          const SizedBox(height: 16),

          // 录音按钮 - 优化触摸响应
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              // 立即设置按压状态，提供即时视觉反馈
              setState(() => _isPressed = true);
              // 触觉反馈
              HapticFeedback.lightImpact();
              // 触发录音
              if (!audioState.isRecording) {
                context.read<AudioBloc>().add(const AudioStartStreamingRecording());
              }
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              if (audioState.isRecording) {
                HapticFeedback.lightImpact();
                if (audioState.isStreamingRecording) {
                  context.read<AudioBloc>().add(const AudioFinalizeStreaming());
                } else {
                  context.read<AudioBloc>().add(const AudioStopRecording());
                }
              }
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              if (audioState.isRecording) {
                if (audioState.isStreamingRecording) {
                  context.read<AudioBloc>().add(const AudioFinalizeStreaming());
                } else {
                  context.read<AudioBloc>().add(const AudioStopRecording());
                }
              }
            },
            onLongPressStart: (_) {
              // 长按也触发，确保兼容性
              if (!_isPressed) {
                setState(() => _isPressed = true);
                HapticFeedback.lightImpact();
                if (!audioState.isRecording) {
                  context.read<AudioBloc>().add(const AudioStartStreamingRecording());
                }
              }
            },
            onLongPressEnd: (_) {
              setState(() => _isPressed = false);
              if (audioState.isRecording) {
                HapticFeedback.lightImpact();
                if (audioState.isStreamingRecording) {
                  context.read<AudioBloc>().add(const AudioFinalizeStreaming());
                } else {
                  context.read<AudioBloc>().add(const AudioStopRecording());
                }
              }
            },
            child: SizedBox(
              width: 160,
              height: 160,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外圈脉冲效果（录音时）
                    if (audioState.isRecording)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 120 * _pulseAnimation.value,
                            height: 120 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFC4A57B).withValues(
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
                        color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.9),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFC4A57B)
                              : const Color(0xFFD9C9B8),
                          width: isActive ? 3 : 2.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFC4A57B).withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 6,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(0xFFD9C9B8).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 3,
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
    );
  }

  /// 构建实时转写区域 - 固定高度,不影响按钮位置
  Widget _buildTranscriptionArea(AudioState audioState) {
    // 固定高度容器,保持布局稳定,优化动画性能
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,  // 使用更流畅的动画曲线
      height: (audioState.isStreamingRecording && audioState.realtimeTranscription != null)
          ? 200  // 转写框显示时的高度(从220减少到200,给上方文案更多空间)
          : 24,  // 收起时的最小高度(从40减少到24,优化间距)
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: (audioState.isStreamingRecording && audioState.realtimeTranscription != null)
          ? _buildRealtimeTranscription(audioState)
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
  Widget _buildRealtimeTranscription(AudioState audioState) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),  // 减少最大高度
      padding: const EdgeInsets.all(14),  // 减少内边距,优化空间利用
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),  // 稍微减小圆角
        border: Border.all(
          color: const Color(0xFFE8DED0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),  // 减弱阴影
            blurRadius: 10,
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
              // 连接状态点
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: audioState.isWebSocketConnected
                      ? const Color(0xFF4CAF50) // 绿色：已连接
                      : const Color(0xFFFF9800), // 橙色：离线
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                audioState.isWebSocketConnected ? '实时识别中' : '离线录音中',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B7D6B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 转写文本
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                audioState.realtimeTranscription ?? '等待识别...',
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
              ),
            ),
          ),
        ],
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
            double scale = 0.7;
            double opacity = 0.25;
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
               scale = 0.7 + (0.3 * factor);
               opacity = 0.25 + (0.75 * factor);
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
