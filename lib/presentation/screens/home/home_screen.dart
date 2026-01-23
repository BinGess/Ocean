/// 首页 - 录音页面
/// 主要功能：长按录音、快速记录

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
import '../../widgets/quick_note_card.dart';
import '../../widgets/loading_overlay.dart';
import '../debug/api_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _completedAudioPath;

  @override
  void initState() {
    super.initState();
    // 加载最近的记录
    context.read<RecordBloc>().add(const RecordLoadList(limit: 5));
  }

  void _handleRecordComplete(String audioPath) {
    setState(() {
      _completedAudioPath = audioPath;
    });

    // 显示处理选择模态框
    ProcessingChoiceModal.show(
      context: context,
      transcription: '正在转写中...',
    ).then((mode) {
      if (mode != null && _completedAudioPath != null) {
        _handleProcessingModeSelected(mode);
      }
    });
  }

  void _handleProcessingModeSelected(ProcessingMode mode) {
    if (_completedAudioPath == null) return;

    // 创建快速笔记
    context.read<RecordBloc>().add(
          RecordCreateQuickNote(
            audioPath: _completedAudioPath!,
            mode: mode,
          ),
        );

    setState(() {
      _completedAudioPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ApiTestScreen(),
                ),
              );
            },
            tooltip: 'API 调试',
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
            child: BlocBuilder<RecordBloc, RecordState>(
              builder: (context, recordState) {
                return Column(
                  children: [
                    // 录音区域
                    Expanded(
                      flex: 2,
                      child: BlocBuilder<AudioBloc, AudioState>(
                        builder: (context, audioState) {
                          return _buildRecordSection(context, audioState);
                        },
                      ),
                    ),

                    // 最近记录列表
                    Expanded(
                      flex: 3,
                      child: _buildRecentRecords(context, recordState),
                    ),
                  ],
                );
              },
            ),
          ),

          // 加载遮罩
          BlocBuilder<RecordBloc, RecordState>(
            builder: (context, state) {
              String? message;
              if (state.isTranscribing) {
                message = '正在转写...';
              } else if (state.isAnalyzing) {
                message = '正在分析...';
              } else if (state.isCreating) {
                message = '正在保存...';
              }

              return LoadingOverlay(
                isLoading: state.isTranscribing ||
                    state.isAnalyzing ||
                    state.isCreating,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            audioState.isRecording ? '松开结束录音' : '长按开始录音',
            style: theme.textTheme.titleLarge?.copyWith(
              color: audioState.isRecording ? Colors.red : theme.primaryColor,
            ),
          ),
          const SizedBox(height: 48),
          RecordButton(
            mode: RecordButtonMode.press,
            isRecording: audioState.isRecording,
            duration: audioState.duration,
            isEnabled: audioState.canRecord,
            onRecordStart: () {
              context.read<AudioBloc>().add(const AudioStartRecording());
            },
            onRecordStop: () {
              context.read<AudioBloc>().add(const AudioStopRecording());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecords(BuildContext context, RecordState recordState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近记录',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    // TODO: 跳转到记录列表页面
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
          ),
          Expanded(
            child: recordState.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notes,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有记录\n长按录音开始记录你的感受',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recordState.records.length,
                    itemBuilder: (context, index) {
                      final record = recordState.records[index];
                      return QuickNoteCard(
                        record: record,
                        onTap: () {
                          // TODO: 打开记录详情
                        },
                        onDelete: () {
                          context.read<RecordBloc>().add(
                                RecordDelete(id: record.id),
                              );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
