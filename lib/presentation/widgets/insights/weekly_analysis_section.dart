import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/weekly_analysis.dart';

class WeeklyAnalysisSection extends StatelessWidget {
  const WeeklyAnalysisSection({
    super.key,
    required this.analysis,
    this.showOverview = true,
    this.showEmotionNeeds = true,
    this.compact = false,
  });

  final WeeklyAnalysis analysis;
  final bool showOverview;
  final bool showEmotionNeeds;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (showOverview)
        _Card(
          title: '本周概览',
          icon: Icons.insights_outlined,
          iconBgColor: AppColors.accentWarm,
          iconColor: AppColors.accent,
          compact: compact,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: '记录数',
                      value: '${analysis.totalRecords}',
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: '活跃天数',
                      value: '${analysis.activeDays}',
                      compact: compact,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: '高峰时段',
                      value: analysis.peakTimeBucket ?? '暂无',
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: '最密集日',
                      value: analysis.busiestWeekday ?? '暂无',
                      compact: compact,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                _buildOverviewSummaryText(analysis.changesSummary),
                maxLines: compact ? 1 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: AppTypography.sectionSubtle.copyWith(
                  color: analysis.changesSummary.isEmpty
                      ? AppColors.textSubtle
                      : AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      if (showEmotionNeeds)
        _Card(
          title: '情绪与需求',
          icon: Icons.favorite_border,
          iconBgColor: const Color(0xFFFFF4E6),
          iconColor: const Color(0xFFFF9500),
          compact: compact,
          child: _SwipeableTagStatsCard(
            moodItems: analysis.topMoods,
            needItems: analysis.topNeeds,
            compact: compact,
          ),
        ),
    ];

    return Column(
      children: children,
    );
  }
}

String _buildOverviewSummaryText(List<String> items) {
  if (items.isEmpty) {
    return '本周数据暂时没有明显变化';
  }
  return items.take(2).join(' · ');
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.child,
    required this.compact,
  });

  final String title;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTypography.sectionTitle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppColors.bgCardSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.sectionSubtle.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            value,
            style: AppTypography.pageTitle.copyWith(
              fontSize: compact ? 18 : 20,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeableTagStatsCard extends StatefulWidget {
  const _SwipeableTagStatsCard({
    required this.moodItems,
    required this.needItems,
    required this.compact,
  });

  final List<WeeklyTagStat> moodItems;
  final List<WeeklyTagStat> needItems;
  final bool compact;

  @override
  State<_SwipeableTagStatsCard> createState() => _SwipeableTagStatsCardState();
}

class _SwipeableTagStatsCardState extends State<_SwipeableTagStatsCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ('高频心情', widget.moodItems),
      ('高频需求', widget.needItems),
    ];
    final maxItems = pages
        .map((page) => page.$2.length)
        .fold<int>(0, (max, count) => count > max ? count : max);
    final rowHeight = widget.compact ? 70 : 76; // 略增高以容纳 vsLastWeek badge
    final baseHeight = widget.compact ? 32 : 40;
    final minHeight = widget.compact ? 124 : 140;
    final maxHeight = widget.compact ? 380 : 430; // 支持最多 5 条
    final pageHeight = (maxItems * rowHeight + baseHeight)
        .clamp(minHeight, maxHeight)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(pages.length, (index) {
                  final isActive = _currentPage == index;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.accentLight
                            : const Color(0xFFFAF8F5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        pages[index].$1,
                        style: AppTypography.sectionSubtle.copyWith(
                          color:
                              isActive ? AppColors.accent : AppColors.textMuted,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '左右滑动查看',
              style: AppTypography.sectionSubtle.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.compact ? 10 : 14),
        SizedBox(
          height: pageHeight,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: pages
                .map(
                  (page) => _TagStatsPage(
                    items: page.$2,
                    compact: widget.compact,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TagStatsPage extends StatelessWidget {
  const _TagStatsPage({
    required this.items,
    required this.compact,
  });

  final List<WeeklyTagStat> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: items.isEmpty
          ? Text(
              '暂无足够标签',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textSubtle,
              ),
            )
          : SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == items.length - 1
                          ? 0
                          : (compact ? 8 : 10),
                    ),
                    child: _TagStatRow(
                      rank: entry.key + 1,
                      item: entry.value,
                      compact: compact,
                    ),
                  ),
                ).toList(),
              ),
            ),
    );
  }
}

class _TagStatRow extends StatelessWidget {
  const _TagStatRow({
    required this.rank,
    required this.item,
    required this.compact,
  });

  final int rank;
  final WeeklyTagStat item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: AppTypography.sectionSubtle.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: AppTypography.bodyPrimary.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${item.count} 次 · ${item.percentage.toStringAsFixed(1)}%',
                      style: AppTypography.sectionSubtle.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (item.avgIntensity != null) ...[
                      Text(
                        ' · 强度 ${item.avgIntensity!.toStringAsFixed(1)}',
                        style: AppTypography.sectionSubtle.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (item.vsLastWeek != null && item.vsLastWeek != 0)
            _VsLastWeekBadge(delta: item.vsLastWeek!),
        ],
      ),
    );
  }
}

class _VsLastWeekBadge extends StatelessWidget {
  const _VsLastWeekBadge({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final color = isUp ? const Color(0xFFE8543A) : const Color(0xFF4CAF7D);
    final icon = isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label = isUp ? '+$delta' : '$delta';

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTypography.sectionSubtle.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
