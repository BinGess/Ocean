import 'package:flutter/services.dart';
import 'dart:convert';
import '../../domain/entities/quote.dart';
import '../datasources/local/hive_database.dart';

/// 文案仓储 - 管理文案数据的持久化和访问
class QuotesRepository {
  final HiveDatabase _hiveDatabase;

  QuotesRepository({required HiveDatabase hiveDatabase})
      : _hiveDatabase = hiveDatabase;

  /// 获取所有文案
  Future<List<Quote>> getAllQuotes() async {
    try {
      // 检查Hive中是否有数据
      final quotesBox = _hiveDatabase.quotesBox;

      if (quotesBox.isEmpty) {
        // 首次使用：从assets加载种子数据
        await _loadSeedQuotes();
      }

      // 从Hive读取所有文案（JSON字符串转Quote对象）
      final quotes = <Quote>[];
      for (final jsonStr in quotesBox.values) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final quote = Quote.fromJson(json);
          quotes.add(quote);
        } catch (e) {
          print('Error parsing quote from JSON: $e');
        }
      }

      return quotes;
    } catch (e) {
      print('Error getting quotes from repository: $e');
      return [];
    }
  }

  /// 从assets加载种子文案数据
  Future<void> _loadSeedQuotes() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/quotes.json');
      final List jsonList = jsonDecode(jsonStr);

      final quotesBox = _hiveDatabase.quotesBox;

      // 将每条文案存入Hive（转换为JSON字符串）
      for (final item in jsonList) {
        final quote = Quote.fromJson(item as Map<String, dynamic>);
        final quoteJson = _quoteToJson(quote);
        await quotesBox.add(quoteJson);
      }

      print('Successfully loaded ${jsonList.length} seed quotes');
    } catch (e) {
      print('Error loading seed quotes: $e');
      rethrow;
    }
  }

  /// 将Quote对象转换为JSON字符串
  String _quoteToJson(Quote quote) {
    final json = {
      'id': quote.id,
      'content': quote.content,
      'author': quote.author,
      'category': _categoryToString(quote.category),
      'targetMoods': quote.targetMoods,
      'timeContext': _timeContextToString(quote.timeContext),
      'weight': quote.weight,
      'createdAt': quote.createdAt.toIso8601String(),
    };
    return jsonEncode(json);
  }

  /// 将QuoteCategory转换为字符串
  String _categoryToString(QuoteCategory category) {
    return {
      QuoteCategory.mindfulness: 'mindfulness',
      QuoteCategory.selfCompassion: 'selfCompassion',
      QuoteCategory.stoicism: 'stoicism',
      QuoteCategory.nvc: 'nvc',
    }[category]!;
  }

  /// 将TimeContext转换为字符串
  String _timeContextToString(TimeContext context) {
    return {
      TimeContext.morning: 'morning',
      TimeContext.afternoon: 'afternoon',
      TimeContext.evening: 'evening',
      TimeContext.anytime: 'anytime',
    }[context]!;
  }

  /// 清空所有文案（用于测试或重置）
  Future<void> clearAllQuotes() async {
    await _hiveDatabase.quotesBox.clear();
  }

  /// 重新加载种子文案（用于更新）
  Future<void> reloadSeedQuotes() async {
    await clearAllQuotes();
    await _loadSeedQuotes();
  }

  /// 根据ID获取单条文案
  Future<Quote?> getQuoteById(String id) async {
    try {
      final quotes = await getAllQuotes();

      for (final quote in quotes) {
        if (quote.id == id) {
          return quote;
        }
      }

      return null;
    } catch (e) {
      print('Error getting quote by id: $e');
      return null;
    }
  }

  /// 获取文案统计信息
  int getQuotesCount() {
    return _hiveDatabase.quotesBox.length;
  }
}
