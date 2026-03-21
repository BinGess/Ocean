import 'dart:async';
import '../../data/datasources/local/hive_database.dart';

/// Pro 订阅服务
/// 管理用户的 Pro 订阅状态
class ProSubscriptionService {
  final HiveDatabase _database;

  static const String _proStatusKey = 'pro_subscription_active';
  static const String _proExpiryKey = 'pro_subscription_expiry';

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  Stream<bool> get statusStream => _statusController.stream;

  ProSubscriptionService({required HiveDatabase database})
      : _database = database;

  /// 当前是否为 Pro 用户
  bool get isPro {
    final active = _database.settingsBox.get(_proStatusKey) as bool? ?? false;
    if (!active) return false;

    final expiryStr = _database.settingsBox.get(_proExpiryKey) as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    return DateTime.now().isBefore(expiry);
  }

  /// 激活 Pro 订阅（购买成功后调用）
  Future<void> activate({required Duration duration}) async {
    final expiry = DateTime.now().add(duration);
    await _database.settingsBox.put(_proStatusKey, true);
    await _database.settingsBox.put(_proExpiryKey, expiry.toIso8601String());
    _statusController.add(true);
  }

  /// 恢复购买
  Future<bool> restorePurchase() async {
    // TODO: 接入真实的 StoreKit / Google Play 恢复购买逻辑
    return isPro;
  }

  void dispose() {
    _statusController.close();
  }
}
