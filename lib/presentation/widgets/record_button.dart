import 'package:flutter/material.dart';

enum RecordButtonMode {
  press, // 长按录音
  toggle, // 点击切换
}

class RecordButton extends StatefulWidget {
  final RecordButtonMode mode;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordStop;
  final bool isRecording;
  final double duration; // 录音时长（秒）
  final bool isEnabled;

  const RecordButton({
    super.key,
    this.mode = RecordButtonMode.press,
    this.onRecordStart,
    this.onRecordStop,
    this.isRecording = false,
    this.duration = 0.0,
    this.isEnabled = true,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // 缩放动画
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 脉冲动画
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isEnabled) return;

    if (widget.mode == RecordButtonMode.toggle) {
      if (widget.isRecording) {
        widget.onRecordStop?.call();
      } else {
        widget.onRecordStart?.call();
      }
    }
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPressStart: widget.mode == RecordButtonMode.press
          ? (_) {
              if (!widget.isEnabled) return;
              widget.onRecordStart?.call();
            }
          : null,
      onLongPressEnd: widget.mode == RecordButtonMode.press
          ? (_) {
              if (!widget.isEnabled) return;
              widget.onRecordStop?.call();
            }
          : null,
      onTap: widget.mode == RecordButtonMode.toggle ? _handleTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 录音按钮
          Stack(
            alignment: Alignment.center,
            children: [
              // 外圈脉冲效果（录音时）
              if (widget.isRecording)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 96 * _pulseAnimation.value,
                      height: 96 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(
                          alpha: (0.3 * (1 - (_pulseAnimation.value - 1) / 0.3))
                              .clamp(0.0, 1.0),
                        ),
                      ),
                    );
                  },
                ),

              // 主按钮
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isRecording ? _scaleAnimation.value : 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isRecording
                            ? Colors.red
                            : (widget.isEnabled
                                ? theme.primaryColor
                                : Colors.grey),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isRecording
                                    ? Colors.red
                                    : theme.primaryColor)
                                .withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 时长显示
          if (widget.isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(widget.duration),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),

          // 提示文本
          if (!widget.isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.mode == RecordButtonMode.press ? '长按录音' : '点击录音',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
