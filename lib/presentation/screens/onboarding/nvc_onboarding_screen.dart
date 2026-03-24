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
///   │ NVC 四维度依次淡入   │
///   │ 「感受」tooltip      │
///   │ CTA 「现在换你来试试」│
///   └─────────────────────┘
///     │ onComplete(skip=false/true)
///     ▼
///   write onboarding_completed = true
///     │
///     ▼
///   MainNavigation

library;

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
  // 四个 NVC 维度的淡入控制器
  final List<AnimationController> _fadeControllers = [];
  final List<Animation<double>> _fadeAnimations = [];

  // 「感受」tooltip 可见性
  bool _tooltipVisible = false;

  // 防止重复完成调用
  bool _completed = false;

  // 各维度的数据
  static const _demo = _DemoData();

  // 减少动画偏好检测（在 build 后读取 MediaQuery）
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    // 为四个维度各创建一个 AnimationController
    for (int i = 0; i < 4; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _fadeControllers.add(controller);
      _fadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOut),
        ),
      );
    }

    // 依次播放，间隔 1 秒（第 0 个立即开始）
    _startSequentialAnimations();
  }

  void _startSequentialAnimations() {
    // 延迟 300ms 后开始，确保 widget 树已完成构建并读取 reduceMotion
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // 读取无障碍设置
      final mediaQuery = MediaQuery.of(context);
      _reduceMotion = mediaQuery.disableAnimations;

      if (_reduceMotion) {
        // 无动画：全部立即显示
        for (final c in _fadeControllers) {
          c.value = 1.0;
        }
        // 感受 tooltip 在 500ms 后触发（无动画模式规范）
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _tooltipVisible = true);
            _scheduleTooltipDismiss();
          }
        });
      } else {
        // 有动画：依次淡入，每隔 1 秒
        for (int i = 0; i < _fadeControllers.length; i++) {
          final idx = i;
          Future.delayed(Duration(milliseconds: i * 1000), () {
            if (!mounted) return;
            _fadeControllers[idx].forward();
            // 「感受」是第 1 个维度（index 1），动画完成后显示 tooltip
            if (idx == 1) {
              _fadeControllers[idx].addStatusListener((status) {
                if (status == AnimationStatus.completed && mounted) {
                  setState(() => _tooltipVisible = true);
                  _scheduleTooltipDismiss();
                }
              });
            }
          });
        }
      }
    });
  }

  void _scheduleTooltipDismiss() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _tooltipVisible) {
        setState(() => _tooltipVisible = false);
      }
    });
  }

  Future<void> _complete() async {
    if (_completed) return;
    _completed = true;

    // 写入 flag
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
    for (final c in _fadeControllers) {
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

                    // 观察
                    FadeTransition(
                      opacity: _fadeAnimations[0],
                      child: _NVCDemoCard(
                        icon: Icons.visibility_outlined,
                        iconColor: const Color(0xFF48697A),
                        iconBgColor: const Color(0xFFE6EEF2),
                        title: '观察',
                        subtitle: '发生了什么（客观事实）',
                        body: _demo.observation,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 感受 + tooltip
                    FadeTransition(
                      opacity: _fadeAnimations[1],
                      child: Column(
                        children: [
                          _NVCDemoCard(
                            icon: Icons.favorite_border,
                            iconColor: const Color(0xFFB28C7F),
                            iconBgColor: const Color(0xFFF3E8E5),
                            title: '感受',
                            subtitle: '你有什么感受',
                            body: _demo.feelings,
                          ),
                          // 感受揭秘提示 tooltip
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _tooltipVisible
                                ? _FeelingsTooltip(
                                    key: const ValueKey('tooltip'),
                                    onDismiss: () {
                                      setState(
                                          () => _tooltipVisible = false);
                                    },
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('no-tooltip')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 需要
                    FadeTransition(
                      opacity: _fadeAnimations[2],
                      child: _NVCDemoCard(
                        icon: Icons.eco_outlined,
                        iconColor: const Color(0xFF8D9D86),
                        iconBgColor: const Color(0xFFE8F0E5),
                        title: '需要',
                        subtitle: '背后未被满足的需要',
                        body: _demo.needs,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 请求
                    FadeTransition(
                      opacity: _fadeAnimations[3],
                      child: _NVCDemoCard(
                        icon: Icons.chat_bubble_outline,
                        iconColor: const Color(0xFFC4A57B),
                        iconBgColor: const Color(0xFFFFF8E7),
                        title: '请求',
                        subtitle: '可以做什么来改善',
                        body: _demo.request,
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 标题标签
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

          // 跳过按钮
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
          const Text(
            '今天开会被打断，很烦。',
            style: TextStyle(
              fontSize: 17,
              color: AppColors.textPrimary,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
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

// ── 示范内容 ──────────────────────────────────────────────────────────────────

class _DemoData {
  const _DemoData();

  String get observation =>
      '在今天下午的项目会议中，我正在发言时被另一位同事打断，我没有机会说完自己的想法。';

  String get feelings => '烦躁、沮丧、有些委屈';

  String get needs => '被尊重、被倾听、在表达中感到安全';

  String get request =>
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
          // 标题行
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
          // 内容
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

// ── 感受揭秘 tooltip ──────────────────────────────────────────────────────────

class _FeelingsTooltip extends StatelessWidget {
  final VoidCallback onDismiss;

  const _FeelingsTooltip({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '注意：这里只写感受词，不写你让我觉得',
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF5C3A31),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 15,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '注意：这里只写感受词，不写「你让我觉得…」',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.close,
                size: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
