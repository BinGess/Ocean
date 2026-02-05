import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/insight_report.dart';

class HistoryReportDetailScreen extends StatelessWidget {
  final InsightReport report;
  final DateTime? cachedAt;

  const HistoryReportDetailScreen({
    super.key,
    required this.report,
    this.cachedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _formatWeekRange(report.weekRange),
          style: const TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      report.reportType,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5D4E3C),
                      ),
                    ),
                    if (cachedAt != null)
                      Text(
                        _formatLastFetchTime(cachedAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB8ADA0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildEmotionOverviewCard(report.emotionOverview),
          ),
          if (report.highFrequencyEmotions.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildHighFrequencySection(report.highFrequencyEmotions),
            ),
          SliverToBoxAdapter(
            child: _buildPatternHypothesisCard(report.patternHypothesis),
          ),
          if (report.actionSuggestions.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildActionSuggestionsSection(report.actionSuggestions),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionOverviewCard(EmotionOverview overview) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_emotions_outlined,
                  size: 18,
                  color: Color(0xFFC4A57B),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '情绪概览',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            overview.summary,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Color(0xFF5D4E3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighFrequencySection(List<HighFrequencyEmotion> emotions) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: const Color(0xFFE8F4EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.format_quote,
                  size: 18,
                  color: Color(0xFF6B9080),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '高频情境',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...emotions.map((emotion) => _buildEmotionItem(emotion)),
        ],
      ),
    );
  }

  Widget _buildEmotionItem(HighFrequencyEmotion emotion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${emotion.content}"',
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF5D4E3C),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: Color(0xFFB8ADA0),
              ),
              const SizedBox(width: 4),
              Text(
                emotion.time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB8ADA0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternHypothesisCard(PatternHypothesis pattern) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E7),
            Color(0xFFFFF5E0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC4A57B).withOpacity(0.15),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: Color(0xFFC4A57B),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '潜在需求',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHighlightedText(pattern),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(PatternHypothesis pattern) {
    String text = pattern.text;
    final tagMap = <String, String>{};
    for (final tag in pattern.highlightTags) {
      tagMap[tag.key] = tag.value;
    }

    final spans = <TextSpan>[];
    final regex = RegExp(r'\{(\w+)\}');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 15,
            height: 1.8,
            color: Color(0xFF5D4E3C),
          ),
        ));
      }

      final key = match.group(1);
      final value = tagMap[key] ?? '{$key}';
      spans.add(TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 15,
          height: 1.8,
          color: key == 'trigger' ? const Color(0xFFE07B3E) : const Color(0xFF8B5CF6),
          fontWeight: FontWeight.w600,
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 15,
          height: 1.8,
          color: Color(0xFF5D4E3C),
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildActionSuggestionsSection(List<ActionSuggestion> suggestions) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: Color(0xFF4A90A4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '行动建议',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(ActionSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4E3C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF8B7D6B),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeekRange(String weekRange) {
    final parts = weekRange.split(' ~ ');
    if (parts.length == 2) {
      try {
        final start = DateTime.parse(parts[0]);
        final end = DateTime.parse(parts[1]);
        final startFormatted = DateFormat('M月d日').format(start);
        final endFormatted = DateFormat('M月d日').format(end);
        return '$startFormatted - $endFormatted';
      } catch (_) {
        return weekRange;
      }
    }
    return weekRange;
  }

  String _formatLastFetchTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚更新';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return DateFormat('M/d HH:mm').format(time);
    }
  }
}

