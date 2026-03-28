import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/pro_subscription_service.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/screens/pro/pro_purchase_screen.dart';

class _FakeProSubscriptionService extends Fake
    implements ProSubscriptionService {
  _FakeProSubscriptionService({
    this.product,
    this.loadingValue = false,
    this.storeAvailableValue = true,
    this.errorValue,
    this.isProValue = false,
  });

  final ProductDetails? product;
  final bool loadingValue;
  final bool storeAvailableValue;
  final String? errorValue;
  final bool isProValue;
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get statusStream => _statusController.stream;

  @override
  bool get isPro => isProValue;

  @override
  ProductDetails? get productDetails => product;

  @override
  bool get loading => loadingValue;

  @override
  bool get storeAvailable => storeAvailableValue;

  @override
  String? get errorMessage => errorValue;

  @override
  String get priceString => product?.price ?? '';

  @override
  Future<bool> purchase() async => false;

  @override
  Future<void> restorePurchases() async {}

  Future<void> dispose() async {
    await _statusController.close();
  }
}

Widget _buildProPurchaseScreen() {
  return const MaterialApp(
    locale: Locale('zh'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProPurchaseScreen(),
  );
}

void main() {
  late _FakeProSubscriptionService fakeService;

  tearDown(() async {
    if (getIt.isRegistered<ProSubscriptionService>()) {
      await fakeService.dispose();
      await getIt.reset();
    }
  });

  testWidgets(
      'ProPurchaseScreen shows loading text while product price is loading',
      (tester) async {
    fakeService = _FakeProSubscriptionService(loadingValue: true);
    getIt.registerSingleton<ProSubscriptionService>(fakeService);

    await tester.pumpWidget(_buildProPurchaseScreen());
    await tester.pump();

    expect(find.text('价格加载中...'), findsOneWidget);
    expect(find.text('立即订阅 — ¥1/月'), findsNothing);
  });

  testWidgets(
      'ProPurchaseScreen shows price unavailable text when product price failed to load',
      (tester) async {
    fakeService = _FakeProSubscriptionService(loadingValue: false);
    getIt.registerSingleton<ProSubscriptionService>(fakeService);

    await tester.pumpWidget(_buildProPurchaseScreen());
    await tester.pump();

    expect(find.text('价格获取失败，请稍后重试'), findsOneWidget);
    expect(find.text('立即订阅 — ¥1/月'), findsNothing);
  });
}
