/// 分析展示相关的共享组件。
/// 同时被 NVC 确认页（[NVCConfirmationModal]）与记录详情页复用，
/// 保证「原文引号卡 / 基础-专业 Tab / 专业方法列表 / 深入分析摘要」
/// 三处入口的视觉与交互一致。
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/deep_analysis_result.dart';
import '../../screens/intervention/deeper_support_screen.dart';

/// 原文卡：引号包裹 + 手写体观感。
/// iOS 走系统手写字体（Hannotate SC / Hanzipen SC），其余平台回退 serif 斜体。
class TranscriptionQuote extends StatelessWidget {
  const TranscriptionQuote({super.key, required this.text});

  final String text;

  static const _handwritingStyle = TextStyle(
    fontFamily: 'Hannotate SC',
    fontFamilyFallback: [
      'Hanzipen SC',
      AppTypography.serifFamily,
      'Source Han Serif SC',
      'serif',
    ],
    fontStyle: FontStyle.italic,
    color: Color(0xFF4A4A4A),
    fontSize: 17,
    height: 1.7,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.bgCardSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“',
            style: TextStyle(
              fontFamily: AppTypography.serifFamily,
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.accent.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 2),
          Text('$text”', style: _handwritingStyle),
        ],
      ),
    );
  }
}

/// 基础分析 / 专业分析 分段 Tab。
class AnalysisTabBar extends StatelessWidget {
  const AnalysisTabBar({
    super.key,
    required this.activeIndex,
    required this.onChanged,
  });

  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCardSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segment(label: '基础分析', index: 0),
          _segment(label: '专业分析', index: 1, withProBadge: true),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required int index,
    bool withProBadge = false,
  }) {
    final isActive = activeIndex == index;
    final isProfessional = index == 1;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : isProfessional
                    ? AppColors.accentLight.withValues(alpha: 0.38)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isProfessional
                ? Border.all(
                    color: AppColors.accent.withValues(
                      alpha: isActive ? 0.18 : 0.12,
                    ),
                  )
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF5D4E3C).withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive || isProfessional
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
              if (withProBadge) ...[
                const SizedBox(width: 6),
                _AnimatedProBadge(isActive: isActive),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedProBadge extends StatelessWidget {
  const _AnimatedProBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final guideScale = isActive ? 1.0 : 1.06 - (0.06 * value);
        final bgAlpha = isActive ? 1.0 : 0.82 + (0.18 * value);
        return Transform.scale(
          scale: guideScale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: bgAlpha),
              borderRadius: BorderRadius.circular(999),
              boxShadow: isActive
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: 0.12 * (1 - value),
                        ),
                        blurRadius: 8 + (8 * (1 - value)),
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: child,
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'Pro',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF8D6A3B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 专业分析方法行：推荐项加 accent 边框 + 角标 + 方法概述。
class AnalysisMethodRow extends StatelessWidget {
  const AnalysisMethodRow({
    super.key,
    required this.recommendation,
    required this.isRecommended,
    required this.hasProAccess,
    required this.onTap,
  });

  final DeeperSupportRecommendation recommendation;
  final bool isRecommended;
  final bool hasProAccess;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isRecommended ? Colors.white : AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecommended
                  ? AppColors.accent.withValues(alpha: 0.55)
                  : AppColors.borderLight,
              width: isRecommended ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            recommendation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isRecommended
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '为此刻推荐',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasProAccess
                        ? Icons.chevron_right_rounded
                        : Icons.lock_outline,
                    size: hasProAccess ? 20 : 15,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${recommendation.methodLabel} · ${recommendation.theorySource}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recommendation.shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF5A5148),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 已生成的深入分析摘要卡。
class DeepAnalysisSummaryCard extends StatelessWidget {
  const DeepAnalysisSummaryCard({
    super.key,
    required this.analysis,
    required this.onTap,
  });

  final DeepAnalysisResult analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 15, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text(
                    '深入分析',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                analysis.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${analysis.methodLabel} · ${analysis.theorySource}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionSubtle.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                analysis.groundedUnderstanding,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF5A5148),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 基础分析信息卡（事实观察 / 感受 / 需要 / 行动 Tips）。
/// [onEdit] 为空时不显示编辑按钮（详情页只读场景）。
class NVCInfoCard extends StatelessWidget {
  const NVCInfoCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.content,
    this.onEdit,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Widget content;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '也许...',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: content),
            ],
          ),
        ],
      ),
    );
  }
}
