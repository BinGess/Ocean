import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../domain/entities/insight_report_cache.dart';
import '../../../domain/repositories/insight_repository.dart';
import 'history_report_detail_screen.dart';

class HistoryReportsScreen extends StatefulWidget {
  const HistoryReportsScreen({super.key});

  @override
  State<HistoryReportsScreen> createState() => _HistoryReportsScreenState();
}

class _HistoryReportsScreenState extends State<HistoryReportsScreen> {
  late Future<List<InsightReportCache>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<InsightRepository>().getAllCachedInsightReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '历史周报',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<InsightReportCache>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A57B)),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildReportCard(context, item);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, InsightReportCache item) {
    final report = item.report;
    final title = _formatWeekRange(report.weekRange);
    final timeText = _formatRelativeTime(item.cachedAt);
    final summary = report.emotionOverview.summary;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HistoryReportDetailScreen(
              report: report,
              cachedAt: item.cachedAt,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E0D8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B8B8B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B6B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          const Text(
            '没有更多历史记录',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeekRange(String weekRange) {
    final parts = weekRange.split('~');
    if (parts.length != 2) return weekRange;
    final start = parts[0].trim();
    final end = parts[1].trim();
    final startDate = DateTime.tryParse(start);
    final endDate = DateTime.tryParse(end);
    if (startDate == null || endDate == null) return weekRange;

    return '${startDate.month}月${startDate.day}日 - ${endDate.month}月${endDate.day}日';
  }

  String _formatRelativeTime(DateTime cachedAt) {
    final now = DateTime.now();
    final diff = now.difference(cachedAt);
    final days = diff.inDays;
    if (days <= 0) return '今天';
    if (days < 7) return '$days天前';
    final weeks = (days / 7).floor();
    if (weeks < 5) return '$weeks周前';
    final months = (days / 30).floor();
    return '$months月前';
  }
}
