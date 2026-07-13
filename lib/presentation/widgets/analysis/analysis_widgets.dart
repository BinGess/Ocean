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
        border: Border.all(color: AppColors.borderLight),
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
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: '$label${isActive ? "，当前选中" : ""}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(index),
            borderRadius: BorderRadius.circular(9),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isActive ? AppColors.border : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                  if (withProBadge) ...[
                    const SizedBox(width: 6),
                    const _ProBadge(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Pro',
        style: TextStyle(
          fontSize: 10,
          color: Color(0xFF8D6A3B),
          fontWeight: FontWeight.w700,
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
    final titleStyle = AppTypography.sectionTitle.copyWith(
      color: AppColors.textPrimary,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecommended
                  ? AppColors.accent.withValues(alpha: 0.72)
                  : AppColors.borderLight,
              width: 1,
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
                            style: titleStyle,
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
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              '为此刻推荐',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8D6A3B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  hasProAccess
                      ? const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        )
                      : const _ProLockedBadge(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${recommendation.methodLabel} · ${recommendation.theorySource}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionSubtle.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                recommendation.shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProLockedBadge extends StatelessWidget {
  const _ProLockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 12, color: Color(0xFF8D6A3B)),
          SizedBox(width: 3),
          Text(
            'Pro',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8D6A3B),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
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
                style: AppTypography.sectionTitle.copyWith(
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
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.textSecondary,
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
    this.showPrompt = true,
    this.onEdit,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Widget content;
  final bool showPrompt;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
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
                  style: AppTypography.sectionTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onEdit != null)
                Semantics(
                  button: true,
                  label: '编辑$title',
                  child: InkResponse(
                    onTap: onEdit,
                    radius: 22,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (showPrompt)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '也许...',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: content),
              ],
            )
          else
            content,
        ],
      ),
    );
  }
}

/// 行动 Tips 内容：将 "1. ...；2. ..." 这类连续文本整理成更易扫读的编号列表。
class NVCActionTipsContent extends StatelessWidget {
  const NVCActionTipsContent({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  static final RegExp _numberedTipPattern =
      RegExp(r'(^|[\s；;。.!?！？])([1-9]\d*)[.．、]\s*');

  @override
  Widget build(BuildContext context) {
    final tips = _extractTips(text);
    if (tips.isEmpty) {
      return Text(text, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < tips.length; index++) ...[
          if (index > 0) ...[
            const SizedBox(height: 10),
            const _ActionTipDivider(),
            const SizedBox(height: 10),
          ],
          _ActionTipRow(
            number: tips[index].number,
            text: tips[index].text,
            style: style,
          ),
        ],
      ],
    );
  }

  static List<_ActionTip> _extractTips(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return const [];

    final matches = _numberedTipPattern.allMatches(trimmed).toList();
    if (matches.isEmpty) return const [];

    final tips = <_ActionTip>[];
    for (var index = 0; index < matches.length; index++) {
      final start = matches[index].end;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : trimmed.length;
      final tip = _cleanTip(trimmed.substring(start, end));
      if (tip.isNotEmpty) {
        tips.add(_ActionTip(number: matches[index].group(2)!, text: tip));
      }
    }
    return tips;
  }

  static String _cleanTip(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^[；;，,。.\s]+'), '')
        .replaceFirst(RegExp(r'[；;\s]+$'), '');
  }
}

class _ActionTip {
  const _ActionTip({required this.number, required this.text});

  final String number;
  final String text;
}

class _ActionTipRow extends StatelessWidget {
  const _ActionTipRow({
    required this.number,
    required this.text,
    required this.style,
  });

  final String number;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentWarm,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.24),
              width: 0.8,
            ),
          ),
          child: Text(
            number,
            style: AppTypography.chipLabel.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: style.copyWith(height: 1.62),
          ),
        ),
      ],
    );
  }
}

class _ActionTipDivider extends StatelessWidget {
  const _ActionTipDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 34),
      color: AppColors.borderLight.withValues(alpha: 0.72),
    );
  }
}
