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
            // 如果正在进行NVC分析，显示NVC结果
            if (state.isNvcAnalyzing || state.nvcAnalysis != null) {
              return _buildNVCResultModal(context, state);
            }

            // 否则显示选项菜单
            return ProcessingChoiceModal(
              transcription: state.transcription ?? '正在转写中...',
              onSelect: (mode) => Navigator.of(context).pop(mode),
              onCancel: () => Navigator.of(context).pop(),
              onNVCInsight: () {
                // 触发 NVC 洞察分析
                final transcription = context.read<RecordBloc>().state.transcription;
                if (transcription != null && transcription.isNotEmpty) {
                  context.read<RecordBloc>().add(RecordNVCInsight(transcription));
                }
              },
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

  void _handleProcessingModeSelected(ProcessingMode mode) {
    if (_completedAudioPath == null) return;

    // 获取当前转写文本（如果有）
    final transcription = context.read<RecordBloc>().state.transcription;

    // 创建快速笔记
    context.read<RecordBloc>().add(
          RecordCreateQuickNote(
            audioPath: _completedAudioPath!,
            mode: mode,
            transcription: transcription,
          ),
        );

    setState(() {
      _completedAudioPath = null;
    });
  }

  /// 构建 NVC 分析结果模态框
  Widget _buildNVCResultModal(BuildContext context, RecordState state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'NVC 洞察',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // 清除NVC分析结果
                    context.read<RecordBloc>().add(
                      const RecordLoadList(limit: 5),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 加载状态
            if (state.isNvcAnalyzing)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text(
                      '正在分析中...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else if (state.nvcAnalysis != null)
              _buildNVCAnalysisResult(context, state.nvcAnalysis!),

            const SizedBox(height: 16),

            // 操作按钮
            if (state.nvcAnalysis != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(ProcessingMode.withNVC);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: const Text('保存记录'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 构建 NVC 分析结果内容
  Widget _buildNVCAnalysisResult(BuildContext context, dynamic nvcAnalysis) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 观察
        _buildSection(
          context,
          title: '观察 (Observation)',
          icon: Icons.visibility,
          color: Colors.blue,
          content: nvcAnalysis.observation,
        ),

        const SizedBox(height: 16),

        // 感受
        if (nvcAnalysis.feelings.isNotEmpty)
          _buildSection(
            context,
            title: '感受 (Feelings)',
            icon: Icons.favorite,
            color: Colors.pink,
            content: nvcAnalysis.feelings
                .map((f) => f.feeling)
                .join('、'),
          ),

        const SizedBox(height: 16),

        // 需要
        if (nvcAnalysis.needs.isNotEmpty)
          _buildSection(
            context,
            title: '需要 (Needs)',
            icon: Icons.psychology,
            color: Colors.purple,
            content: nvcAnalysis.needs
                .map((n) => n.need)
                .join('、'),
          ),

        const SizedBox(height: 16),

        // 请求
        if (nvcAnalysis.request != null && nvcAnalysis.request!.isNotEmpty)
          _buildSection(
            context,
            title: '请求 (Request)',
            icon: Icons.chat_bubble_outline,
            color: Colors.green,
            content: nvcAnalysis.request!,
          ),

        // AI洞察
        if (nvcAnalysis.insight != null && nvcAnalysis.insight!.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'AI 洞察',
                icon: Icons.lightbulb,
                color: Colors.amber,
                content: nvcAnalysis.insight!,
              ),
            ],
          ),
      ],
    );
  }

  /// 构建 NVC 分析的单个区域
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
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
            isEnabled: audioState.canRecord || audioState.isRecording, // 关键修复：录音中也必须允许点击，才能触发停止
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
