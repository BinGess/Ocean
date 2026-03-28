/// NVC 新用户教育漏斗 — 引导页
///
/// 首次启动时展示一条示范日记，NVC 四个维度依次淡入，
/// 帮助用户在第一个会话内理解「观察/感受/需要/请求」。
///
/// 入口条件：settingsBox['onboarding_completed'] != true
///
/// 流程图：
///
///   启动
///     │
///     ▼
///   SplashScreen
///     │
///     ▼
///   onboarding_completed == false?
///     │ Yes                │ No
///     ▼                    ▼
///   NVCOnboardingScreen  MainNavigation
///     │
///   ┌─┴──────────────────┐
///   │ 「跳过」按钮         │
///   │ 原始记录打字机效果   │
///   │ NVC 四维度依次滑入   │
///   │ CTA 「现在换你来试试」│
///   └─────────────────────┘
///     │ onComplete(skip=false/true)
///     ▼
///   write onboarding_completed = true
///     │
///     ▼
///   MainNavigation

library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../core/di/injection.dart';

class NVCOnboardingScreen extends StatefulWidget {
  /// 引导完成后调用（跳过或点击 CTA 均触发）
  final VoidCallback onComplete;

  const NVCOnboardingScreen({super.key, required this.onComplete});

  @override
  State<NVCOnboardingScreen> createState() => _NVCOnboardingScreenState();
}

class _NVCOnboardingScreenState extends State<NVCOnboardingScreen>
    with TickerProviderStateMixin {
  // 原始记录打字机
  static const _entryText = '今天开会被打断，很烦。';
  late final AnimationController _typingController;
  late final Animation<int> _typingAnimation;

  // 四个 NVC 维度的滑入+淡入控制器
  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _fadeAnimations = [];
  final List<Animation<Offset>> _slideAnimations = [];

  final List<Timer> _timers = [];

  // 防止重复完成调用
  bool _completed = false;

  // 各维度的数据
  static const _demo = _DemoData();

  // 减少动画偏好检测
  bool _reduceMotion = false;

  // 打字机每字间隔 (ms)
  static const _msPerChar = 80;
  // 打字开始延迟
  static const _typingDelayMs = 300;
  // NVC 卡片开始时间 = 打字延迟 + 打字时长 + 停顿
  static final _nvcStartMs =
      _typingDelayMs + _entryText.length * _msPerChar + 400;
  // 卡片间隔
  static const _nvcIntervalMs = 800;

  @override
  void initState() {
    super.initState();

    // 打字机控制器
    final typingTotalMs = _typingDelayMs + _entryText.length * _msPerChar;
    _typingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: typingTotalMs),
    );
    _typingAnimation = IntTween(begin: 0, end: _entryText.length)
        .animate(CurvedAnimation(
      parent: _typingController,
      curve: Interval(
        _typingDelayMs / typingTotalMs,
        1.0,
        curve: Curves.linear,
      ),
    ));

    // 四个 NVC 卡片控制器（滑入+淡入）
    for (int i = 0; i < 4; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      );
      _cardControllers.add(controller);
      _fadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        ),
      );
      _slideAnimations.add(
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        ),
      );
    }

    _reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (_reduceMotion) {
      _typingController.value = 1.0;
      for (final c in _cardControllers) {
        c.value = 1.0;
      }
    } else {
      _typingController.forward();
      _startSequentialAnimations();
    }
  }

  void _startSequentialAnimations() {
    for (int i = 0; i < _cardControllers.length; i++) {
      final delay = _nvcStartMs + i * _nvcIntervalMs;
      _timers.add(Timer(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _cardControllers[i].forward();
      }));
    }
  }

  Future<void> _complete() async {
    if (_completed) return;
    _completed = true;

    try {
      final db = getIt<HiveDatabase>();
      await db.settingsBox.put('onboarding_completed', true);
    } catch (e) {
      debugPrint('NVCOnboarding: 写入 flag 失败: $e');
    }

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _typingController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶部栏：进度标识 + 跳过 ──────────────────
            _buildTopBar(context),

            // ── 主体内容（可滚动） ─────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildOriginalEntry(),
                    const SizedBox(height: 16),
                    _buildNVCLabel(),
                    const SizedBox(height: 12),

                    // 事实观察
                    _buildAnimatedCard(
                      index: 0,
                      card: const _NVCDemoCard(
                        icon: Icons.visibility_outlined,
                        iconColor: Color(0xFF48697A),
                        iconBgColor: Color(0xFFE6EEF2),
                        title: '事实观察',
                        subtitle: '客观描述发生的事',
                        body: _DemoData.observationText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 我现在的感受
                    _buildAnimatedCard(
                      index: 1,
                      card: const _NVCDemoCard(
                        icon: Icons.favorite_border,
                        iconColor: Color(0xFFB28C7F),
                        iconBgColor: Color(0xFFF3E8E5),
                        title: '我现在的感受',
                        subtitle: '此刻的情绪状态',
                        body: _DemoData.feelingsText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 我需要
                    _buildAnimatedCard(
                      index: 2,
                      card: const _NVCDemoCard(
                        icon: Icons.eco_outlined,
                        iconColor: Color(0xFF8D9D86),
                        iconBgColor: Color(0xFFE8F0E5),
                        title: '我需要',
                        subtitle: '未被满足的深层需求',
                        body: _DemoData.needsText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 行动 Tips
                    _buildAnimatedCard(
                      index: 3,
                      card: const _NVCDemoCard(
                        icon: Icons.tips_and_updates_outlined,
                        iconColor: Color(0xFFC4A57B),
                        iconBgColor: Color(0xFFFFF8E7),
                        title: '行动 Tips',
                        subtitle: '具体可行的下一步',
                        body: _DemoData.requestText,
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── 底部 CTA ─────────────────────────────────
            _buildCTA(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget card}) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: card,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '快速了解 NVC',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '跳过引导',
            child: TextButton(
              onPressed: _complete,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textTertiary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '跳过',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '先看一个例子',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '这是一条真实感的情绪记录，看看 App 是如何理解它的。',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalEntry() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_outlined,
                  size: 16, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                '原始记录',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _typingAnimation,
            builder: (context, _) {
              final displayed =
                  _entryText.substring(0, _typingAnimation.value);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayed,
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.textPrimary,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // 光标闪烁
                  if (_typingAnimation.value < _entryText.length)
                    _TypingCursor(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNVCLabel() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'NVC 分析',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _complete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '现在换你来试试',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 打字光标 ──────────────────────────────────────────────────────────────────

class _TypingCursor extends StatefulWidget {
  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(
        width: 2,
        height: 18,
        margin: const EdgeInsets.only(left: 1, bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── 示范内容 ──────────────────────────────────────────────────────────────────

class _DemoData {
  const _DemoData();

  static const observationText =
      '在今天下午的项目会议中，我正在发言时被另一位同事打断，我没有机会说完自己的想法。';

  static const feelingsText = '烦躁、沮丧、有些委屈';

  static const needsText = '被尊重、被倾听、在表达中感到安全';

  static const requestText =
      '下次开会时，可以和同事提前约定：发言时尽量等对方说完再发表意见。';
}

// ── 只读 NVC 卡片 ─────────────────────────────────────────────────────────────

class _NVCDemoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String body;

  const _NVCDemoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
