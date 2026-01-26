/// 首页 - 录音页面
/// 主要功能：长按录音、快速记录

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/record.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_state.dart';
import '../../bloc/audio/audio_event.dart';
import '../../bloc/record/record_bloc.dart';
import '../../bloc/record/record_state.dart';
import '../../bloc/record/record_event.dart';
import '../../widgets/record_button.dart';
import '../../widgets/processing_choice_modal.dart';
import '../../widgets/mood_selection_modal.dart';
import '../../widgets/nvc_confirmation_modal.dart';
import '../../widgets/loading_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

    // 触发转写
    context.read<RecordBloc>().add(RecordTranscribe(audioPath));

    // 显示处理选择模态框
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

  void _handleProcessingModeSelected(ProcessingMode mode) async {
    if (_completedAudioPath == null) return;

    // 获取当前转写文本（如果有）
    final transcription = context.read<RecordBloc>().state.transcription;

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
        _clearCompletedAudio();
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
          _clearCompletedAudio();
        }
        break;

      case ProcessingMode.withNVC:
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
           _clearCompletedAudio();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0, // 防止滚动时状态栏变色
        surfaceTintColor: Colors.transparent, // 防止 Material 3 自动着色
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 28,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: CircleAvatar(
              backgroundColor: Colors.grey[100],
              radius: 22,
              child: const Icon(Icons.person_outline, color: Colors.black87),
            ),
          ),
        ],
      ),
      body: Stack(
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
                 // NVC 分析完成，显示确认框
                  if (recordState.isAnalyzed && recordState.nvcAnalysis != null) {
                     // 确保在 widget 树构建完成后再显示弹窗
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (ModalRoute.of(context)?.isCurrent ?? false) {
                         NVCConfirmationModal.show(
                           context: context, 
                           initialAnalysis: recordState.nvcAnalysis!,
                           transcription: recordState.transcription ?? '',
                           onRevert: () {
                              // 用户选择还原为仅记录
                              _handleProcessingModeSelected(ProcessingMode.onlyRecord);
                           },
                         ).then((updatedAnalysis) {
                            if (updatedAnalysis != null && _completedAudioPath != null) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('正在后台保存记录...')),
                               );
                               context.read<RecordBloc>().add(
                                 RecordCreateQuickNote(
                                   audioPath: _completedAudioPath!,
                                   mode: ProcessingMode.withNVC,
                                   transcription: recordState.transcription,
                                   nvcAnalysis: updatedAnalysis,
                                 ),
                               );
                               _clearCompletedAudio();
                            }
                         });
                       }
                     });
                  }
                 
                 // 创建成功提示
                 if (recordState.isSuccess && recordState.latestRecord != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('记录已保存')),
                    );
                 }
              },
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildDescriptionSection(context),
                  ),
                  Expanded(
                    flex: 2,
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
    );
  }

  Widget _buildRecordSection(BuildContext context, AudioState audioState) {
    final theme = Theme.of(context);

    // 权限被拒绝
    if (!audioState.hasPermission &&
        audioState.status == RecordingStatus.permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text('需要录音权限才能使用此功能'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<AudioBloc>().add(
                      const AudioRequestPermission(),
                    );
              },
              child: const Text('授予权限'),
            ),
          ],
        ),
      );
    }

    // 正常录音界面
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    audioState.isRecording ? '点击结束录音' : '点击开始录音',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: audioState.isRecording ? Colors.red : theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 48),
                  RecordButton(
                    mode: RecordButtonMode.toggle,
                    isRecording: audioState.isRecording,
                    duration: audioState.duration,
                    isEnabled: audioState.canRecord || audioState.isRecording,
                    onRecordStart: () {
                      context.read<AudioBloc>().add(const AudioStartRecording());
                    },
                    onRecordStop: () {
                      context.read<AudioBloc>().add(const AudioStopRecording());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return PageView.builder(
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
            
            // Calculate styles based on distance from center
            double scale = 0.8; // 默认更小
            double opacity = 0.3;
            Color color = Colors.grey[300]!;
            FontWeight fontWeight = FontWeight.normal;

            if (distance < 0.5) {
               // Active item (Center)
               scale = 1.6; // 放大当前行
               opacity = 1.0;
               color = const Color(0xFF2C3E50);
               fontWeight = FontWeight.w900;
            } else if (distance < 1.5) {
               // Neighboring items
               double factor = 1.0 - (distance - 0.5);
               scale = 0.8 + (0.8 * factor); // 过渡
               opacity = 0.3 + (0.7 * factor);
               color = Color.lerp(Colors.grey[300]!, const Color(0xFF2C3E50), factor)!;
               if (factor > 0.5) fontWeight = FontWeight.w600;
            }

            return Center(
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      _rollingDescriptions[textIndex],
                      style: TextStyle(
                        color: color,
                        fontSize: 24, // 基础字号加大
                        fontWeight: fontWeight,
                        height: 1.2, // 稍微紧凑一点的行高
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
