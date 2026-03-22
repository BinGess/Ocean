import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/weekly_analysis.dart';

class WeeklyAnalysisSection extends StatelessWidget {
  const WeeklyAnalysisSection({
    super.key,
    required this.analysis,
    this.showOverview = true,
    this.showEmotionNeeds = true,
  });

  final WeeklyAnalysis analysis;
  final bool showOverview;
  final bool showEmotionNeeds;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (showOverview)
        _Card(
          title: '本周概览',
          icon: Icons.insights_outlined,
          iconBgColor: AppColors.accentWarm,
          iconColor: AppColors.accent,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: '记录数',
                      value: '${analysis.totalRecords}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: '活跃天数',
                      value: '${analysis.activeDays}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: '高峰时段',
                      value: analysis.peakTimeBucket ?? '暂无',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: '最密集日',
                      value: analysis.busiestWeekday ?? '暂无',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _buildOverviewSummaryText(analysis.changesSummary),
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
          child: _SwipeableTagStatsCard(
            moodItems: analysis.topMoods,
            needItems: analysis.topNeeds,
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
  });

  final String title;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const SizedBox(height: 16),
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.pageTitle.copyWith(
              fontSize: 20,
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
  });

  final List<WeeklyTagStat> moodItems;
  final List<WeeklyTagStat> needItems;

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
    final pageHeight = (maxItems * 72 + 40).clamp(140, 320).toDouble();

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
        const SizedBox(height: 14),
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
  });

  final List<WeeklyTagStat> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            Text(
              '暂无足够标签',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textSubtle,
              ),
            )
          else
            ...items.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == items.length - 1 ? 0 : 10,
                    ),
                    child: _TagStatRow(
                      rank: entry.key + 1,
                      item: entry.value,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _TagStatRow extends StatelessWidget {
  const _TagStatRow({
    required this.rank,
    required this.item,
  });

  final int rank;
  final WeeklyTagStat item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 6),
                Text(
                  '${item.count} 次 · ${item.percentage.round()}%',
                  style: AppTypography.sectionSubtle.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
