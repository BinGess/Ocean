import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/core/services/ocean_account_service.dart';
import 'package:mindflow/presentation/screens/account/account_entry_screen.dart';

void main() {
  late _FakeOceanAccountService accountService;

  setUp(() {
    accountService = _FakeOceanAccountService();
    if (getIt.isRegistered<OceanAccountService>()) {
      getIt.unregister<OceanAccountService>();
    }
    getIt.registerSingleton<OceanAccountService>(accountService);
  });

  tearDown(() {
    if (getIt.isRegistered<OceanAccountService>()) {
      getIt.unregister<OceanAccountService>();
    }
  });

  testWidgets('未同意用户协议和隐私政策时不能获取短信验证码', (tester) async {
    await tester.pumpWidget(_buildTestable());

    await tester.enterText(
        find.widgetWithText(TextField, '手机号'), '13800138000');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(accountService.sendSmsCodeCount, 0);
    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
  });

  testWidgets('同意用户协议和隐私政策后可以获取短信验证码', (tester) async {
    await tester.pumpWidget(_buildTestable());

    await tester.enterText(
        find.widgetWithText(TextField, '手机号'), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(accountService.sendSmsCodeCount, 1);
    expect(accountService.smsCodeSentTo, '13800138000');
    expect(find.text('验证码已发送，5 分钟内有效'), findsOneWidget);
  });

  testWidgets('未同意用户协议和隐私政策时不能邮箱登录或注册', (tester) async {
    await tester.pumpWidget(_buildTestable());

    await tester.tap(find.text('邮箱登录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '邮箱'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '密码（至少 8 位）'),
      'password123',
    );

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '注册并进入'));
    await tester.pump();

    expect(accountService.loginCount, 0);
    expect(accountService.registerCount, 0);
    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
  });

  testWidgets('用户协议和隐私政策链接打开内置文档页', (tester) async {
    await tester.pumpWidget(_buildTestable());

    await tester.tap(find.text('《用户协议》'));
    await tester.pumpAndSettle();
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('账号使用'), findsOneWidget);

    Navigator.of(tester.element(find.text('用户协议'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('《隐私政策》'));
    await tester.pumpAndSettle();
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('我们收集的信息'), findsOneWidget);
  });
}

Widget _buildTestable() {
  return MaterialApp(
    home: AccountEntryScreen(
      onComplete: () {},
      onSkip: () {},
    ),
  );
}

class _FakeOceanAccountService extends Fake implements OceanAccountService {
  int sendSmsCodeCount = 0;
  int loginCount = 0;
  int registerCount = 0;
  String? smsCodeSentTo;

  @override
  Future<void> sendSmsCode({required String phone}) async {
    sendSmsCodeCount += 1;
    smsCodeSentTo = phone;
  }

  @override
  Future<OceanAuthTokens> loginWithSms({
    required String phone,
    required String code,
  }) async {
    return const OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<OceanAuthTokens> login({
    required String email,
    required String password,
  }) async {
    loginCount += 1;
    return OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      email: email,
    );
  }

  @override
  Future<OceanAuthTokens> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    registerCount += 1;
    return OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      email: email,
    );
  }
}
