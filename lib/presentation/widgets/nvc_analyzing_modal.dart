import 'dart:math' as math;
import 'package:flutter/material.dart';

/// NVC分析加载动画弹窗
/// 展示更友好的分析过程动画，替代简单的loading spinner
class NVCAnalyzingModal extends StatefulWidget {
  final String transcription;

  const NVCAnalyzingModal({
    super.key,
    required this.transcription,
  });

  @override
  State<NVCAnalyzingModal> createState() => _NVCAnalyzingModalState();

  static Future<void> show({
    required BuildContext context,
    required String transcription,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => NVCAnalyzingModal(transcription: transcription),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}

class _NVCAnalyzingModalState extends State<NVCAnalyzingModal>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _sparkleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  int _currentStep = 0;
  final List<_AnalysisStep> _steps = [
    _AnalysisStep(
      icon: Icons.remove_red_eye_outlined,
      title: '识别事实观察',
      color: const Color(0xFF4CAF50),
    ),
    _AnalysisStep(
      icon: Icons.favorite,
      title: '分析情绪感受',
      color: const Color(0xFFFF9500),
    ),
    _AnalysisStep(
      icon: Icons.spa_outlined,
      title: '理解内在需要',
      color: const Color(0xFF34C759),
    ),
    _AnalysisStep(
      icon: Icons.lightbulb_outline,
      title: '生成行动建议',
      color: const Color(0xFFFFB300),
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 脉冲动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // 进度动画
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    // 闪烁动画
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 模拟步骤进度
    _startStepAnimation();
  }

  void _startStepAnimation() async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _currentStep = i;
      });
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 顶部拖动条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 32),

          // 主要内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // 动画图标区域
                  _buildAnimatedIcon(),

                  const SizedBox(height: 32),

                  // 标题
                  const Text(
                    '正在分析你的感受',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 副标题
                  Text(
                    '使用NVC非暴力沟通框架',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 步骤列表
                  _buildStepsList(),

                  const SizedBox(height: 32),

                  // 转写文本预览
                  _buildTranscriptionPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外圈脉冲
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 100 * _pulseAnimation.value,
                height: 100 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC4A57B).withOpacity(0.3),
                    width: 2,
                  ),
                ),
              );
            },
          ),

          // 闪烁粒子
          AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(6, (index) {
                  final angle = (index * 60 + _sparkleController.value * 360) *
                      math.pi /
                      180;
                  final radius = 45 + math.sin(_sparkleController.value * math.pi * 2 + index) * 5;
                  final opacity = 0.3 + math.sin(_sparkleController.value * math.pi * 2 + index * 0.5) * 0.4;
                  return Transform.translate(
                    offset: Offset(
                      math.cos(angle) * radius,
                      math.sin(angle) * radius,
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC4A57B).withOpacity(opacity.clamp(0.0, 1.0)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          // 中心图标
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC4A57B).withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 32,
                  color: Color(0xFFC4A57B),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final isCompleted = index < _currentStep;
        final isCurrent = index == _currentStep;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? Colors.white
                : (isCompleted ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(16),
            border: isCurrent
                ? Border.all(color: step.color.withOpacity(0.5), width: 1.5)
                : null,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: step.color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // 图标
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent || isCompleted
                      ? step.color.withOpacity(0.15)
                      : const Color(0xFFF0F0F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : step.icon,
                  size: 20,
                  color: isCurrent || isCompleted
                      ? step.color
                      : const Color(0xFFBBBBBB),
                ),
              ),

              const SizedBox(width: 16),

              // 标题
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isCurrent || isCompleted
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFAAAAAA),
                  ),
                ),
              ),

              // 进度指示
              if (isCurrent)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(step.color),
                  ),
                )
              else if (isCompleted)
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: step.color,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTranscriptionPreview() {
    final preview = widget.transcription.length > 80
        ? '${widget.transcription.substring(0, 80)}...'
        : widget.transcription;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 16,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Text(
                '分析内容',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5D4E3C),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisStep {
  final IconData icon;
  final String title;
  final Color color;

  const _AnalysisStep({
    required this.icon,
    required this.title,
    required this.color,
  });
}
