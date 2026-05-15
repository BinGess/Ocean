import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../data/datasources/local/hive_database.dart';

/// Pro 订阅服务
/// 使用 in_app_purchase 接入 iOS StoreKit 真实订阅
class ProSubscriptionService {
  final HiveDatabase _database;
  final InAppPurchase _iap = InAppPurchase.instance;

  /// App Store Connect 中配置的月度订阅商品 ID
  static const String monthlySubscriptionId = 'mindflow_pro_monthly';

  static const String _proStatusKey = 'pro_subscription_active';
  static const String _proExpiryKey = 'pro_subscription_expiry';
  static const String _proProductIdKey = 'pro_subscription_product_id';

  /// 关于页连点 Logo 解锁后，才显示 DEBUG 开关（持久化）
  static const String _debugMenuUnlockedKey = 'debug_menu_unlocked';

  /// DEBUG 模式：免订阅使用导出（仅内部测试）
  static const String _debugModeKey = 'app_debug_mode_enabled';

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  final StreamController<void> _priceController =
      StreamController<void>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Stream<bool> get statusStream => _statusController.stream;

  /// 价格信息更新时广播（加载成功或失败后触发，UI 可监听此 stream 刷新）
  Stream<void> get priceStream => _priceController.stream;

  /// 当前可用的商品信息（从 App Store 获取）
  ProductDetails? _productDetails;
  ProductDetails? get productDetails => _productDetails;

  /// IAP 是否可用
  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// 是否正在加载商品
  bool _loading = false;
  bool get loading => _loading;

  /// 购买/恢复过程中的错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ProSubscriptionService({required HiveDatabase database})
      : _database = database;

  /// 初始化 IAP，监听购买流，加载商品信息
  Future<void> init() async {
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      debugPrint('[ProSubscription] Store not available');
      return;
    }

    // 监听购买更新流
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('[ProSubscription] Purchase stream error: $error');
      },
    );

    // 加载商品信息
    await _loadProducts();
  }

  /// 从 App Store 加载商品信息（可被外部调用以重试）
  Future<void> _loadProducts() async {
    _loading = true;
    try {
      final response = await _iap.queryProductDetails({monthlySubscriptionId});
      if (response.error != null) {
        debugPrint('[ProSubscription] Query products error: ${response.error}');
        return;
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            '[ProSubscription] Products not found: ${response.notFoundIDs}');
      }
      if (response.productDetails.isNotEmpty) {
        _productDetails = response.productDetails.first;
        debugPrint(
            '[ProSubscription] Product loaded: ${_productDetails!.title} - ${_productDetails!.price}');
      }
    } catch (e) {
      debugPrint('[ProSubscription] Load products failed: $e');
    } finally {
      _loading = false;
      _priceController.add(null); // 通知 UI 价格状态已更新（无论成功或失败）
    }
  }

  /// 主动重新拉取价格（供 UI 在打开页面或点击重试时调用）
  Future<void> reloadProducts() async {
    if (_loading) return;
    if (!_storeAvailable) {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) return;
    }
    await _loadProducts();
  }

  /// 当前是否为 Pro 用户（仅真实订阅，不含 DEBUG）
  bool get isPro {
    final active = _database.settingsBox.get(_proStatusKey) as bool? ?? false;
    if (!active) return false;

    final expiryStr = _database.settingsBox.get(_proExpiryKey) as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    return DateTime.now().isBefore(expiry);
  }

  /// 关于页已解锁 DEBUG 区域（连点 Logo 3 次）
  bool get debugMenuUnlocked =>
      _database.settingsBox.get(_debugMenuUnlockedKey) as bool? ?? false;

  Future<void> setDebugMenuUnlocked(bool value) async {
    await _database.settingsBox.put(_debugMenuUnlockedKey, value);
  }

  /// DEBUG 模式开启时，导出等同 Pro，无需购买
  bool get isDebugModeEnabled =>
      _database.settingsBox.get(_debugModeKey) as bool? ?? false;

  Future<void> setDebugModeEnabled(bool value) async {
    await _database.settingsBox.put(_debugModeKey, value);
  }

  /// 是否可使用 Pro 限定功能（真实订阅或 DEBUG）
  bool get hasProFeatureAccess => isPro || isDebugModeEnabled;

  /// 发起购买
  Future<bool> purchase() async {
    _errorMessage = null;

    if (!_storeAvailable) {
      _errorMessage = 'Store not available';
      return false;
    }

    if (_productDetails == null) {
      await _loadProducts();
      if (_productDetails == null) {
        _errorMessage = 'product_not_available'; // UI 层用本地化字符串替换
        return false;
      }
    }

    final purchaseParam = PurchaseParam(productDetails: _productDetails!);
    try {
      // 自动续期订阅使用 buyNonConsumable
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _errorMessage = 'Purchase could not be initiated';
        return false;
      }
      return true; // 购买流程已发起，结果通过 purchaseStream 回调
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ProSubscription] Purchase failed: $e');
      return false;
    }
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    _errorMessage = null;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ProSubscription] Restore failed: $e');
    }
  }

  /// 处理购买更新回调
  Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      debugPrint(
          '[ProSubscription] Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndActivate(purchase);
          break;
        case PurchaseStatus.error:
          _errorMessage = purchase.error?.message ?? 'Unknown error';
          _statusController.add(false);
          debugPrint(
              '[ProSubscription] Purchase error: ${purchase.error?.message}');
          break;
        case PurchaseStatus.canceled:
          _statusController.add(false);
          debugPrint('[ProSubscription] Purchase canceled');
          break;
        case PurchaseStatus.pending:
          debugPrint('[ProSubscription] Purchase pending');
          break;
      }

      // 完成交易（必须调用，否则 iOS 会反复弹出购买确认）
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// 验证并激活订阅
  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    // 注意：生产环境应该将 receipt 发送到自己的服务器进行验证
    // 这里采用客户端本地验证（适合小型 App 快速上线）
    try {
      if (purchase.productID == monthlySubscriptionId) {
        await _activateSubscription(
          productId: purchase.productID,
          duration: const Duration(days: 30),
        );
      }
    } catch (e) {
      debugPrint('[ProSubscription] Verify/activate failed: $e');
      _statusController.add(false);
    }
  }

  /// 激活 Pro 订阅
  Future<void> _activateSubscription({
    required String productId,
    required Duration duration,
  }) async {
    final expiry = DateTime.now().add(duration);
    await _database.settingsBox.put(_proStatusKey, true);
    await _database.settingsBox.put(_proExpiryKey, expiry.toIso8601String());
    await _database.settingsBox.put(_proProductIdKey, productId);
    _statusController.add(true);
    debugPrint('[ProSubscription] Activated until ${expiry.toIso8601String()}');
  }

  /// 获取商品价格展示文本（从 App Store 动态获取）
  String get priceString {
    if (_productDetails != null) {
      return _productDetails!.price;
    }
    return '¥1/月'; // 默认回退
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _statusController.close();
    _priceController.close();
  }
}
