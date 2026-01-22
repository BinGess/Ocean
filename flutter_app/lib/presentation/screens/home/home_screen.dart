/// 首页 - 录音页面
/// 主要功能：长按录音、快速记录

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/audio/audio_bloc.dart';
import '../../bloc/audio/audio_state.dart';
import '../../bloc/audio/audio_event.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 打开设置页面
            },
          ),
        ],
      ),
      body: BlocBuilder<AudioBloc, AudioState>(
        builder: (context, state) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 欢迎文本
                Text(
                  '长按录音，记录此刻感受',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 48),

                // 录音按钮
                _RecordButton(state: state),

                const SizedBox(height: 24),

                // 状态文本
                if (state.isRecording)
                  Text(
                    '录音中... ${state.duration.toStringAsFixed(1)}s',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                if (state.hasError && state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),

                // 权限提示
                if (!state.hasPermission &&
                    state.status == RecordingStatus.permissionDenied)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('需要录音权限才能使用此功能'),
                        const SizedBox(height: 8),
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
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 录音按钮组件
class _RecordButton extends StatelessWidget {
  final AudioState state;

  const _RecordButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final isRecording = state.isRecording;

    return GestureDetector(
      onLongPressStart: (_) {
        if (state.canRecord) {
          context.read<AudioBloc>().add(const AudioStartRecording());
        }
      },
      onLongPressEnd: (_) {
        if (isRecording) {
          context.read<AudioBloc>().add(const AudioStopRecording());
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : [],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }
}
