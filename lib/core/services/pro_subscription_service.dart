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

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Stream<bool> get statusStream => _statusController.stream;

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

    // 必须先监听 purchaseStream，再做任何其他操作。
    // purchaseStream 会自动投递上次未完成的待处理交易（包括用户已付款但 App
    // 崩溃/关闭导致未激活的订单），由 _onPurchaseUpdate 统一处理并调用
    // completePurchase，不要手动通过 SKPaymentQueueWrapper 清除交易。
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('[ProSubscription] Purchase stream error: $error');
      },
    );

    // 加载商品信息
    await _loadProducts();
  }

  /// 从 App Store 加载商品信息
  Future<void> _loadProducts() async {
    _loading = true;
    try {
      final response = await _iap.queryProductDetails({monthlySubscriptionId});
      if (response.error != null) {
        debugPrint(
            '[ProSubscription] Query products error: ${response.error}');
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
    }
  }

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

  /// 发起购买
  Future<bool> purchase() async {
    _errorMessage = null;

    if (!_storeAvailable) {
      _errorMessage = 'Store not available';
      return false;
    }

    if (_productDetails == null) {
      // 重试加载一次
      await _loadProducts();
      if (_productDetails == null) {
        _errorMessage = 'Product not available';
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
          '[ProSubscription] Purchase update: ${purchase.productID} '
          '- status=${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 先激活，再完成交易。即使激活失败也必须 completePurchase，
          // 否则 iOS 会反复弹出未完成交易的确认弹窗（卡单）。
          try {
            await _verifyAndActivate(purchase);
          } catch (e) {
            debugPrint('[ProSubscription] Activate failed: $e');
          }
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

      // 无论成功还是失败，都必须完成交易，防止卡单
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// 验证并激活订阅
  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    if (purchase.productID == monthlySubscriptionId) {
      await _activateSubscription(
        productId: purchase.productID,
        duration: const Duration(days: 30),
      );
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
  }
}
