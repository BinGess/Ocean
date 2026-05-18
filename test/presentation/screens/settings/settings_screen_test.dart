import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/ai_auth_service.dart';
import 'package:mindflow/core/services/locale_service.dart';
import 'package:mindflow/core/services/ocean_account_service.dart';
import 'package:mindflow/core/services/pro_subscription_service.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/bloc/locale/locale_bloc.dart';
import 'package:mindflow/presentation/screens/settings/settings_screen.dart';

class _FakeSettingsBox extends Fake implements Box<dynamic> {
  final Map<String, dynamic> _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _store.containsKey(key) ? _store[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key as String] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _store.remove(key);
  }
}

class _FakeHiveDatabase extends Fake implements HiveDatabase {
  final _FakeSettingsBox _settingsBox = _FakeSettingsBox();

  @override
  Box<dynamic> get settingsBox => _settingsBox;
}

class _FakeAIAuthService extends Fake implements AIAuthService {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateStream => _controller.stream;

  @override
  Future<bool> get isAuthorized async => false;

  void disposeFake() => _controller.close();
}

class _FakeProSubscriptionService extends Fake
    implements ProSubscriptionService {
  @override
  bool get hasProFeatureAccess => false;
}

class _FakeOceanAccountService extends Fake implements OceanAccountService {
  _FakeOceanAccountService({required this.signedIn});

  bool signedIn;
  int logoutCount = 0;
  String? phone = '186****3732';
  String? email;

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<String?> get currentPhone async => phone;

  @override
  Future<String?> get currentEmail async => email;

  @override
  Future<void> logout() async {
    logoutCount += 1;
    signedIn = false;
  }
}

Widget _buildTestable({required HiveDatabase database}) {
  final localeBloc = LocaleBloc(LocaleService(database));

  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: BlocProvider<LocaleBloc>.value(
      value: localeBloc,
      child: const SettingsScreen(),
    ),
  );
}

void main() {
  late _FakeHiveDatabase fakeDb;
  late _FakeAIAuthService fakeAIAuthService;
  late _FakeOceanAccountService fakeAccountService;

  setUp(() {
    fakeDb = _FakeHiveDatabase();
    fakeAIAuthService = _FakeAIAuthService();
    fakeAccountService = _FakeOceanAccountService(signedIn: true);

    getIt
      ..registerSingleton<HiveDatabase>(fakeDb)
      ..registerSingleton<AIAuthService>(fakeAIAuthService)
      ..registerSingleton<ProSubscriptionService>(
        _FakeProSubscriptionService(),
      )
      ..registerSingleton<OceanAccountService>(fakeAccountService);
  });

  tearDown(() {
    fakeAIAuthService.disposeFake();
    if (getIt.isRegistered<AIAuthService>()) {
      getIt.unregister<AIAuthService>();
    }
    if (getIt.isRegistered<ProSubscriptionService>()) {
      getIt.unregister<ProSubscriptionService>();
    }
    if (getIt.isRegistered<OceanAccountService>()) {
      getIt.unregister<OceanAccountService>();
    }
    if (getIt.isRegistered<HiveDatabase>()) {
      getIt.unregister<HiveDatabase>();
    }
  });

  testWidgets('已登录时设置页底部提供二次确认的退出登录入口', (tester) async {
    await tester.pumpWidget(_buildTestable(database: fakeDb));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '退出登录'),
      400,
      scrollable: find.byType(Scrollable),
    );

    expect(find.widgetWithText(OutlinedButton, '退出登录'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('确认退出登录？'), findsOneWidget);
    expect(fakeAccountService.logoutCount, 0);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '退出登录'));
    await tester.pumpAndSettle();

    expect(fakeAccountService.logoutCount, 1);
    expect(find.widgetWithText(OutlinedButton, '退出登录'), findsNothing);
  });

  testWidgets('设置页不展示 iCloud 同步入口', (tester) async {
    await tester.pumpWidget(_buildTestable(database: fakeDb));
    await tester.pumpAndSettle();

    expect(find.text('iCloud 云同步'), findsNothing);
    expect(find.text('云端备份状态'), findsNothing);
    expect(find.text('账号同步'), findsNothing);
  });

  testWidgets('未登录状态下设置页也不展示 iCloud 同步入口', (tester) async {
    fakeAccountService.signedIn = false;

    await tester.pumpWidget(_buildTestable(database: fakeDb));
    await tester.pumpAndSettle();

    expect(find.text('iCloud 云同步'), findsNothing);
    expect(find.text('云端备份状态'), findsNothing);
    expect(find.text('账号同步'), findsNothing);
  });

  testWidgets('设置页第一组展示账号信息入口并可进入详情', (tester) async {
    await fakeDb.settingsBox.put('profile_avatar', '鲸');
    await fakeDb.settingsBox.put('profile_nickname', '大黄鱼');
    await fakeDb.settingsBox.put('profile_signature', '今天也在认真记录');

    await tester.pumpWidget(_buildTestable(database: fakeDb));
    await tester.pumpAndSettle();

    expect(find.text('账号'), findsOneWidget);
    expect(find.text('账号信息'), findsOneWidget);
    expect(find.text('查看手机号、昵称、头像和签名'), findsOneWidget);

    await tester.tap(find.text('账号信息'));
    await tester.pumpAndSettle();

    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('186****3732'), findsOneWidget);
    expect(find.text('昵称'), findsOneWidget);
    expect(find.text('大黄鱼'), findsWidgets);
    expect(find.text('头像'), findsOneWidget);
    expect(find.text('签名'), findsOneWidget);
    expect(find.text('今天也在认真记录'), findsWidgets);
  });

  testWidgets('未登录时账号信息页底部提供登录入口', (tester) async {
    fakeAccountService.signedIn = false;

    await tester.pumpWidget(_buildTestable(database: fakeDb));
    await tester.pumpAndSettle();

    await tester.tap(find.text('账号信息'));
    await tester.pumpAndSettle();

    final loginButtonFinder = find.widgetWithText(FilledButton, '登录');
    expect(loginButtonFinder, findsOneWidget);

    await tester.tap(loginButtonFinder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '手机号'), findsOneWidget);
    expect(find.text('登录 Ocean 账号'), findsNothing);
  });
}
