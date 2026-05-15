import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/pro_subscription_service.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/screens/pro/pro_purchase_screen.dart';

class _FakeProSubscriptionService extends Fake
    implements ProSubscriptionService {
  final _statusController = StreamController<bool>.broadcast();
  final _priceController = StreamController<void>.broadcast();

  @override
  Stream<bool> get statusStream => _statusController.stream;

  @override
  Stream<void> get priceStream => _priceController.stream;

  @override
  bool get isPro => false;

  @override
  bool get loading => false;

  @override
  ProductDetails? get productDetails => null;

  @override
  String get priceString => '¥1';

  @override
  Future<void> reloadProducts() async {}

  void disposeFake() {
    _statusController.close();
    _priceController.close();
  }
}

void main() {
  late _FakeProSubscriptionService fakeProService;

  setUp(() {
    fakeProService = _FakeProSubscriptionService();
    getIt.registerSingleton<ProSubscriptionService>(fakeProService);
  });

  tearDown(() {
    fakeProService.disposeFake();
    if (getIt.isRegistered<ProSubscriptionService>()) {
      getIt.unregister<ProSubscriptionService>();
    }
  });

  testWidgets('Pro 购买页只展示导出权益，不展示 iCloud 权益', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProPurchaseScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('导出所有记录'), findsOneWidget);
    expect(find.text('iCloud 云同步'), findsNothing);
    expect(find.textContaining('iCloud'), findsNothing);
  });
}
