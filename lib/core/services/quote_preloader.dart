import 'package:flutter/foundation.dart';
import '../../data/repositories/quotes_repository.dart';
import '../../domain/entities/quote.dart';

/// 文案预加载器 - 支持离线模式和性能优化
class QuotePreloader {
  final QuotesRepository _quotesRepository;

  // 缓存的所有文案（内存缓存）
  List<Quote>? _cachedQuotes;

  // 预加载状态
  bool _isPreloading = false;
  bool _isPreloaded = false;

  QuotePreloader({required QuotesRepository quotesRepository})
      : _quotesRepository = quotesRepository;

  /// 获取缓存状态
  bool get isPreloaded => _isPreloaded;
  bool get isPreloading => _isPreloading;

  /// 预加载所有文案到内存（离线模式支持）
  Future<void> preload() async {
    if (_isPreloading || _isPreloaded) {
      return;  // 避免重复预加载
    }

    _isPreloading = true;
    try {
      // 从仓储获取文案（会自动从assets或Hive加载）
      _cachedQuotes = await _quotesRepository.getAllQuotes();
      _isPreloaded = true;
      debugPrint('Successfully preloaded ${_cachedQuotes?.length ?? 0} quotes');
    } catch (e) {
      debugPrint('Error preloading quotes: $e');
      _cachedQuotes = [];
      _isPreloaded = false;
    } finally {
      _isPreloading = false;
    }
  }

  /// 获取所有预加载的文案（离线可用）
  List<Quote> getCachedQuotes() {
    return _cachedQuotes ?? [];
  }

  /// 清空缓存
  void clearCache() {
    _cachedQuotes = null;
    _isPreloaded = false;
  }

  /// 刷新缓存（重新加载）
  Future<void> refreshCache() async {
    clearCache();
    await preload();
  }

  /// 获取缓存大小信息
  Map<String, dynamic> getCacheInfo() {
    return {
      'is_preloaded': _isPreloaded,
      'is_preloading': _isPreloading,
      'quotes_count': _cachedQuotes?.length ?? 0,
      'cache_size_kb': (_cachedQuotes?.length ?? 0) * 0.5,  // 估算大小
    };
  }
}
