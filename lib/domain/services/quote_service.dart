import 'package:flutter/foundation.dart';
import '../entities/quote.dart';
import '../entities/record.dart';

/// 文案推荐服务 - 基于时间、情绪、活跃度的智能推荐
class QuoteService {
  /// 获取推荐文案（从所有文案中选择最适合当前用户的一条）
  static Future<Quote?> getRecommendedQuote({
    required List<Quote> allQuotes,
    required List<Record>? recentRecords,
  }) async {
    if (allQuotes.isEmpty) return null;

    // 1. 获取当前时间段
    final timeContext = _getTimeContext(DateTime.now());

    // 2. 获取用户相关情绪（昨日或本周主导情绪）
    final userMoods = _getUserRelevantMoods(recentRecords);

    // 3. 检查用户是否久未记录（3+天）
    final daysSinceRecord = _daysSinceLastRecord(recentRecords);

    // 4. 计算推荐分数并排序
    double calculateScore(Quote quote) {
      double score = quote.weight;

      // 时间偏好加权 (+0.5)
      if (quote.timeContext == timeContext ||
          quote.timeContext == TimeContext.anytime) {
        score += 0.5;
      }

      // 情绪匹配加权 (+0-1.0)
      if (userMoods.isNotEmpty) {
        final moodMatch = quote.targetMoods
            .where((m) => userMoods.contains(m))
            .length;
        score += (moodMatch / quote.targetMoods.length) * 1.0;
      }

      // 久不记录加权 (+0.3)
      if (daysSinceRecord >= 3) {
        score += 0.3;
      }

      return score;
    }

    // 5. 排序并返回最高分的文案
    final sortedQuotes = List<Quote>.from(allQuotes);
    sortedQuotes.sort((a, b) => calculateScore(b).compareTo(calculateScore(a)));

    return sortedQuotes.isNotEmpty ? sortedQuotes.first : null;
  }

  /// 获取当前时间段
  static TimeContext _getTimeContext(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) {
      return TimeContext.morning;
    } else if (hour >= 21 || hour < 3) {
      return TimeContext.evening;
    } else {
      return TimeContext.afternoon;
    }
  }

  /// 获取用户相关情绪（优先昨日情绪，其次本周主导情绪）
  static List<String> _getUserRelevantMoods(List<Record>? records) {
    if (records == null || records.isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    // 1. 查找昨日的记录
    final yesterdayRecords = records
        .where((r) {
          final recordDate = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
          return recordDate == yesterday;
        })
        .toList();

    if (yesterdayRecords.isNotEmpty) {
      return _extractMoodsFromRecords(yesterdayRecords);
    }

    // 2. 如果没有昨日记录，查找本周主导情绪（过去7天）
    final weekAgo = DateTime(now.year, now.month, now.day - 7);
    final weekRecords = records
        .where((r) => r.createdAt.isAfter(weekAgo) && r.createdAt.isBefore(now))
        .toList();

    if (weekRecords.isNotEmpty) {
      return _extractMoodsFromRecords(weekRecords);
    }

    return [];
  }

  /// 从记录列表中提取情绪标签
  static List<String> _extractMoodsFromRecords(List<Record> records) {
    final moods = <String>{};

    for (final record in records) {
      // 从NVC分析中提取情绪
      if (record.nvc != null && record.nvc!.feelings.isNotEmpty) {
        for (final feeling in record.nvc!.feelings) {
          moods.add(feeling.feeling);
        }
      }

      // 从用户标记的情绪中提取
      if (record.moods != null && record.moods!.isNotEmpty) {
        moods.addAll(record.moods!);
      }
    }

    return moods.toList();
  }

  /// 计算距离最后一条记录的天数
  static int _daysSinceLastRecord(List<Record>? records) {
    if (records == null || records.isEmpty) {
      return 999;  // 无记录时返回大值
    }

    // 找到最近的记录
    final sortedRecords = List<Record>.from(records);
    sortedRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final lastRecord = sortedRecords.first;
    final now = DateTime.now();

    // 计算天数差
    final lastDate = DateTime(lastRecord.createdAt.year, lastRecord.createdAt.month, lastRecord.createdAt.day);
    final today = DateTime(now.year, now.month, now.day);

    final difference = today.difference(lastDate);
    return difference.inDays;
  }

  /// 根据分类获取文案列表
  static List<Quote> getQuotesByCategory({
    required List<Quote> allQuotes,
    required QuoteCategory category,
  }) {
    return allQuotes.where((quote) => quote.category == category).toList();
  }

  /// 根据目标情绪获取相关文案
  static List<Quote> getQuotesByMood({
    required List<Quote> allQuotes,
    required String mood,
  }) {
    return allQuotes
        .where((quote) => quote.targetMoods.contains(mood))
        .toList();
  }

  /// 根据时间获取相关文案
  static List<Quote> getQuotesByTimeContext({
    required List<Quote> allQuotes,
    required TimeContext timeContext,
  }) {
    return allQuotes
        .where((quote) =>
            quote.timeContext == timeContext ||
            quote.timeContext == TimeContext.anytime)
        .toList();
  }
}
