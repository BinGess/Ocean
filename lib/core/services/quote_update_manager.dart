import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/repositories/quotes_repository.dart';
import '../../domain/entities/quote.dart';
import '../../data/datasources/local/hive_database.dart';

/// 语录更新管理器 - 支持定期更新和版本控制
class QuoteUpdateManager {
  final QuotesRepository _quotesRepository;
  final HiveDatabase _hiveDatabase;

  // 更新间隔（默认7天）
  static const Duration _defaultUpdateInterval = Duration(days: 7);

  // 版本存储键
  static const String _versionKey = 'quote_version';
  static const String _lastUpdateKey = 'quote_last_update';

  // 当前版本
  static const String _currentVersion = '1.0.0';

  // 更新状态流
  final _updateStatusController = StreamController<QuoteUpdateStatus>.broadcast();
  Stream<QuoteUpdateStatus> get updateStatusStream => _updateStatusController.stream;

  bool _isUpdating = false;

  QuoteUpdateManager({
    required QuotesRepository quotesRepository,
    required HiveDatabase hiveDatabase,
  })  : _quotesRepository = quotesRepository,
        _hiveDatabase = hiveDatabase;

  /// 检查是否需要更新
  Future<bool> shouldUpdate({Duration? customInterval}) async {
    try {
      final lastUpdateStr = _getLastUpdateTime();
      if (lastUpdateStr == null) {
        return true;  // 从未更新过
      }

      final lastUpdate = DateTime.parse(lastUpdateStr);
      final interval = customInterval ?? _defaultUpdateInterval;

      return DateTime.now().difference(lastUpdate) > interval;
    } catch (e) {
      debugPrint('Error checking update status: $e');
      return false;
    }
  }

  /// 执行更新（重新加载种子文案）
  Future<bool> update() async {
    if (_isUpdating) {
      return false;  // 正在更新，避免重复
    }

    _isUpdating = true;
    _updateStatusController.add(QuoteUpdateStatus.updating);

    try {
      // 重新加载文案
      await _quotesRepository.reloadSeedQuotes();

      // 更新版本和时间
      _setLastUpdateTime();

      _updateStatusController.add(QuoteUpdateStatus.success);
      debugPrint('Successfully updated quotes to version $_currentVersion');
      return true;
    } catch (e) {
      debugPrint('Error updating quotes: $e');
      _updateStatusController.add(QuoteUpdateStatus.error);
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  /// 自动更新（定期检查并更新）
  Future<void> setupAutoUpdate({Duration? checkInterval}) async {
    final interval = checkInterval ?? const Duration(hours: 1);

    // 启动定时器，定期检查更新
    Timer.periodic(interval, (_) async {
      if (!_isUpdating && await shouldUpdate()) {
        await update();
      }
    });
  }

  /// 获取最后一次更新时间
  String? _getLastUpdateTime() {
    try {
      final lastUpdateStr = _hiveDatabase.settingsBox.get(_lastUpdateKey);
      return lastUpdateStr is String ? lastUpdateStr : null;
    } catch (e) {
      debugPrint('Error getting last update time: $e');
      return null;
    }
  }

  /// 设置最后一次更新时间
  void _setLastUpdateTime() {
    try {
      final now = DateTime.now().toIso8601String();
      _hiveDatabase.settingsBox.put(_lastUpdateKey, now);
      debugPrint('Last update time: $now');
    } catch (e) {
      debugPrint('Error setting last update time: $e');
    }
  }

  /// 获取更新信息
  Map<String, dynamic> getUpdateInfo() {
    return {
      'current_version': _currentVersion,
      'is_updating': _isUpdating,
      'update_interval_hours': _defaultUpdateInterval.inHours,
    };
  }

  /// 清理资源
  void dispose() {
    _updateStatusController.close();
  }
}

/// 更新状态枚举
enum QuoteUpdateStatus {
  updating,   // 更新中
  success,    // 更新成功
  error,      // 更新失败
  noUpdate,   // 无更新
}
