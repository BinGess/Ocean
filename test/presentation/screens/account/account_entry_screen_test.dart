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

  testWidgets('登录页隐藏邮箱登录入口', (tester) async {
    await tester.pumpWidget(_buildTestable());

    expect(find.text('邮箱登录'), findsNothing);
    expect(find.widgetWithText(TextField, '邮箱'), findsNothing);
    expect(find.widgetWithText(TextField, '密码（至少 8 位）'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '注册并进入'), findsNothing);
  });

  testWidgets('登录页不展示多余标题并将验证码按钮收进验证码输入框', (tester) async {
    await tester.pumpWidget(_buildTestable());

    expect(find.text('登录 Ocean 账号'), findsNothing);

    final codeInputFinder = find.widgetWithText(TextField, '验证码');
    expect(codeInputFinder, findsOneWidget);
    expect(
      find.descendant(
        of: codeInputFinder,
        matching: find.text('获取验证码'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('获取验证码后进入60秒倒计时并禁止重复点击', (tester) async {
    await tester.pumpWidget(_buildTestable());

    await tester.enterText(
        find.widgetWithText(TextField, '手机号'), '13800138000');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(accountService.sendSmsCodeCount, 1);
    expect(find.text('60秒'), findsOneWidget);

    await tester.tap(find.text('60秒'));
    await tester.pump();

    expect(accountService.sendSmsCodeCount, 1);
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

  testWidgets('本地迁移失败后再次点击登录会重试迁移而不是重新校验验证码', (tester) async {
    accountService.loginWithSmsError =
        const OceanLocalMigrationException('本机数据上传失败');
    await tester.pumpWidget(_buildTestable());

    await tester.enterText(
        find.widgetWithText(TextField, '手机号'), '13800138000');
    await tester.enterText(find.widgetWithText(TextField, '验证码'), '123456');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(accountService.smsLoginCount, 1);
    expect(find.text('重试上传本机数据'), findsOneWidget);

    accountService.loginWithSmsError = null;
    await tester.tap(find.widgetWithText(FilledButton, '重试上传本机数据'));
    await tester.pumpAndSettle();

    expect(accountService.smsLoginCount, 1);
    expect(accountService.retryLocalMigrationCount, 1);
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
  int smsLoginCount = 0;
  int retryLocalMigrationCount = 0;
  String? smsCodeSentTo;
  Object? loginWithSmsError;

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
    smsLoginCount += 1;
    final error = loginWithSmsError;
    if (error != null) throw error;
    return const OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<void> retryLocalMigration() async {
    retryLocalMigrationCount += 1;
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
