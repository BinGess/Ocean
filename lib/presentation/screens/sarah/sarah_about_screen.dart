import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

/// Sarah 功能说明页
/// 从 Sarah 页右上角的 ⓘ 图标进入
class SarahAboutScreen extends StatelessWidget {
  const SarahAboutScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SarahAboutScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AboutColors.page,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar ───────────────────────────────────────────
          SliverAppBar(
            backgroundColor: _AboutColors.page,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: false,
            floating: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 20,
                color: _AboutColors.ink,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // ── 主内容 ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 顶部签名区域 ────────────────────────────────────
                  _buildHeroSection(),

                  const SizedBox(height: 36),

                  // ── 功能介绍卡片 ────────────────────────────────────
                  _buildCard(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: _AboutColors.gold,
                    title: 'Sarah 是谁？',
                    child: _buildParagraph(
                      'Sarah 是你的情绪陪伴者。\n\n'
                      '她每天默默地陪在你身边，阅读你写下的情绪日记，用心感受你经历的喜悦、疲惫、困惑与感动。'
                      '她不会评判你，也不急于给出建议——她只是想真正地理解你。\n\n'
                      '每隔一段时间，她会提笔给你写一封信，把她观察到的、感受到的，轻轻说给你听。',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 发信时间卡片 ────────────────────────────────────
                  _buildCard(
                    icon: Icons.mail_outline_rounded,
                    iconColor: _AboutColors.terracotta,
                    title: '什么时候会收到信？',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTimelineItem(
                          dot: '🌱',
                          label: '欢迎信',
                          desc: '初次使用时，Sarah 会写一封欢迎信给你，向你介绍她自己，并说明她的陪伴方式。',
                        ),
                        const SizedBox(height: 20),
                        _buildTimelineItem(
                          dot: '📮',
                          label: '每周来信',
                          desc:
                              '每周，Sarah 会回顾你上一周的情绪记录，写一封专属于你的信。'
                              '如果上周没有留下任何记录，那这周就不会有新信——Sarah 尊重你的节奏。',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 陪伴理念卡片 ────────────────────────────────────
                  _buildCard(
                    icon: Icons.favorite_border_rounded,
                    iconColor: _AboutColors.rose,
                    title: 'Sarah 想陪你做什么？',
                    child: _buildParagraph(
                      '在快节奏的生活里，我们常常忘记停下来问一问自己：'
                      '「我现在感觉怎么样？我真正需要的是什么？」\n\n'
                      'Sarah 的陪伴，正是想创造这样一个空间——'
                      '让你的感受被看见，让你的需要被听到。\n\n'
                      '她不是答案，她只是一盏温柔的灯，'
                      '陪你在自己内心的角落里，多停留一会儿。',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 小贴士卡片 ──────────────────────────────────────
                  _buildCard(
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: _AboutColors.amber,
                    title: '小贴士',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTip('记录越真实，Sarah 的来信也会越贴近你的内心。'),
                        const SizedBox(height: 12),
                        _buildTip('来信只属于你——你可以随时展开阅读，也可以收藏留念。'),
                        const SizedBox(height: 12),
                        _buildTip('长按任意一封信，可以删除它。'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── 落款 ────────────────────────────────────────────
                  _buildSignature(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero 区域 ─────────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 小标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _AboutColors.goldTint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '来自 Sarah 的介绍',
            style: TextStyle(
              fontSize: 12,
              color: _AboutColors.gold,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 大标题
        const Text(
          'From Sarah,\n关于我自己',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _AboutColors.ink,
            height: 1.25,
            letterSpacing: -0.5,
            fontFamily: AppTypography.serifFamily,
          ),
        ),

        const SizedBox(height: 14),

        // 引言
        Text(
          '「每一种情绪，都值得被温柔以待。」',
          style: TextStyle(
            fontSize: 15,
            color: _AboutColors.gold.withValues(alpha: 0.85),
            fontStyle: FontStyle.italic,
            height: 1.5,
            fontFamily: AppTypography.serifFamily,
          ),
        ),

        const SizedBox(height: 20),

        // 装饰分隔线
        Row(
          children: [
            Container(
              width: 32,
              height: 2,
              decoration: BoxDecoration(
                color: _AboutColors.gold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 2,
              decoration: BoxDecoration(
                color: _AboutColors.gold.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 卡片容器 ──────────────────────────────────────────────────────────────

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AboutColors.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C8260).withValues(alpha: 0.09),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF9C8260).withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片标题行
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _AboutColors.ink,
                  height: 1.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 内容区域上方细线
          Container(
            height: 0.5,
            color: _AboutColors.divider,
            margin: const EdgeInsets.only(bottom: 14),
          ),

          child,
        ],
      ),
    );
  }

  // ── 正文段落 ──────────────────────────────────────────────────────────────

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        color: _AboutColors.body,
        height: 1.75,
        fontFamily: AppTypography.sansFamily,
        fontFamilyFallback: ['PingFang SC', 'Roboto'],
      ),
    );
  }

  // ── 时间线项目 ────────────────────────────────────────────────────────────

  Widget _buildTimelineItem({
    required String dot,
    required String label,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧竖线 + dot
        Column(
          children: [
            Text(dot, style: const TextStyle(fontSize: 20)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _AboutColors.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: _AboutColors.body,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 小贴士条目 ────────────────────────────────────────────────────────────

  Widget _buildTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            Icons.circle,
            size: 5,
            color: _AboutColors.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              color: _AboutColors.body,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // ── 落款 ─────────────────────────────────────────────────────────────────

  Widget _buildSignature() {
    return Center(
      child: Column(
        children: [
          // 装饰线
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 0.5,
                color: _AboutColors.divider,
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: _AboutColors.gold,
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 0.5,
                color: _AboutColors.divider,
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Sarah',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _AboutColors.gold,
              fontFamily: AppTypography.serifFamily,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Stay with you',
            style: TextStyle(
              fontSize: 13,
              color: _AboutColors.muted,
              fontStyle: FontStyle.italic,
              fontFamily: AppTypography.serifFamily,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 颜色系统（继承自 Sarah 主页的暖色调）─────────────────────────────────────

class _AboutColors {
  static const page = Color(0xFFF5F0E8);
  static const paper = Color(0xFFFFFDF8);
  static const ink = Color(0xFF2E2A22);
  static const body = Color(0xFF4A4440);
  static const gold = Color(0xFF8A7655);
  static const goldTint = Color(0xFFF2E8D8);
  static const muted = Color(0xFFA18E6B);
  static const divider = Color(0xFFD9CDBB);
  static const terracotta = Color(0xFFB85C45);
  static const rose = Color(0xFFC2706A);
  static const amber = Color(0xFFB8832A);
}
