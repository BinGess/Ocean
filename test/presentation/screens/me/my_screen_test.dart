import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/ocean_account_service.dart';
import 'package:mindflow/core/theme/app_colors.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/bloc/insight/insight_bloc.dart';
import 'package:mindflow/presentation/bloc/insight/insight_event.dart';
import 'package:mindflow/presentation/bloc/insight/insight_state.dart';
import 'package:mindflow/presentation/screens/me/my_screen.dart';

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
}

class _FakeHiveDatabase extends Fake implements HiveDatabase {
  final _FakeSettingsBox _settingsBox = _FakeSettingsBox();

  @override
  Box<dynamic> get settingsBox => _settingsBox;
}

class _FakeInsightBloc extends Fake implements InsightBloc {
  final List<InsightEvent> addedEvents = [];

  @override
  InsightState get state => InsightState.initial();

  @override
  Stream<InsightState> get stream => const Stream.empty();

  @override
  void add(InsightEvent event) {
    addedEvents.add(event);
  }

  @override
  Future<void> close() async {}
}

class _FakeOceanAccountService extends Fake implements OceanAccountService {
  _FakeOceanAccountService({required this.signedIn});

  bool signedIn;

  @override
  Future<bool> get isSignedIn async => signedIn;
}

Widget _buildTestable({
  required InsightBloc insightBloc,
  WidgetBuilder? accountScreenBuilder,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: BlocProvider<InsightBloc>.value(
      value: insightBloc,
      child: MyScreen(
        proScreenBuilder: (_) => const Scaffold(body: Text('Pro 测试页')),
        settingsScreenBuilder: (_) => const Scaffold(body: Text('设置测试页')),
        accountScreenBuilder: accountScreenBuilder,
      ),
    ),
  );
}

void main() {
  late _FakeHiveDatabase fakeDb;
  late _FakeInsightBloc fakeInsightBloc;

  setUp(() {
    fakeDb = _FakeHiveDatabase();
    fakeInsightBloc = _FakeInsightBloc();

    if (getIt.isRegistered<HiveDatabase>()) {
      getIt.unregister<HiveDatabase>();
    }
    getIt.registerSingleton<HiveDatabase>(fakeDb);
  });

  tearDown(() {
    if (getIt.isRegistered<HiveDatabase>()) {
      getIt.unregister<HiveDatabase>();
    }
    if (getIt.isRegistered<OceanAccountService>()) {
      getIt.unregister<OceanAccountService>();
    }
    if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
      getIt<OceanAccountDataRefreshService>().dispose();
      getIt.unregister<OceanAccountDataRefreshService>();
    }
  });

  testWidgets('我的页点击头像、昵称或签名都可以编辑头像和昵称', (tester) async {
    await tester.pumpWidget(_buildTestable(insightBloc: fakeInsightBloc));
    await tester.pump();

    expect(find.byTooltip('编辑个人信息'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));

    await tester.tap(find.text('MindFlow 用户'));
    await tester.pumpAndSettle();

    expect(find.text('编辑个人信息'), findsOneWidget);
    expect(find.widgetWithText(TextField, '头像'), findsOneWidget);
    expect(find.widgetWithText(TextField, '昵称'), findsOneWidget);
    expect(find.widgetWithText(TextField, '签名'), findsOneWidget);
    expect(find.widgetWithText(TextField, '用户名'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '头像'), '🌊');
    await tester.enterText(find.widgetWithText(TextField, '昵称'), '小海');
    await tester.enterText(find.widgetWithText(TextField, '签名'), '保持流动');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('小海'), findsOneWidget);
    expect(find.text('保持流动'), findsOneWidget);
    expect(find.text('🌊'), findsOneWidget);
    expect(find.text('@ocean'), findsNothing);
    expect(fakeDb.settingsBox.get('profile_avatar'), '🌊');
    expect(fakeDb.settingsBox.get('profile_nickname'), '小海');
    expect(fakeDb.settingsBox.get('profile_signature'), '保持流动');
    expect(fakeDb.settingsBox.get('profile_username'), isNull);

    await tester.tap(find.text('🌊'));
    await tester.pumpAndSettle();
    expect(find.text('编辑个人信息'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保持流动'));
    await tester.pumpAndSettle();
    expect(find.text('编辑个人信息'), findsOneWidget);
  });

  testWidgets('账号数据刷新通知会重新加载本周概览', (tester) async {
    final refreshService = OceanAccountDataRefreshService();
    getIt.registerSingleton<OceanAccountDataRefreshService>(refreshService);
    addTearDown(() {
      if (getIt.isRegistered<OceanAccountDataRefreshService>()) {
        getIt<OceanAccountDataRefreshService>().dispose();
        getIt.unregister<OceanAccountDataRefreshService>();
      }
    });

    await tester.pumpWidget(_buildTestable(insightBloc: fakeInsightBloc));
    await tester.pump();
    final initialReloadCount = fakeInsightBloc.addedEvents
        .whereType<InsightAccountDataChanged>()
        .length;

    refreshService.notifyChanged();
    await tester.pump();

    expect(
      fakeInsightBloc.addedEvents.whereType<InsightAccountDataChanged>().length,
      initialReloadCount + 1,
    );
  });

  testWidgets('我的页提供管理订阅和更多设置入口', (tester) async {
    await tester.pumpWidget(_buildTestable(insightBloc: fakeInsightBloc));
    await tester.pump();

    expect(find.text('管理订阅'), findsOneWidget);
    expect(find.text('更多设置'), findsOneWidget);

    await tester.tap(find.text('管理订阅'));
    await tester.pumpAndSettle();
    expect(find.text('Pro 测试页'), findsOneWidget);

    Navigator.of(tester.element(find.text('Pro 测试页'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('更多设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置测试页'), findsOneWidget);
  });

  testWidgets('我的页本周概览缺省态保留概览骨架和引导信息', (tester) async {
    await tester.pumpWidget(_buildTestable(insightBloc: fakeInsightBloc));
    await tester.pump();

    expect(find.text('本周概览'), findsOneWidget);
    expect(find.text('记录数'), findsOneWidget);
    expect(find.text('活跃天数'), findsOneWidget);
    expect(find.text('高峰时段'), findsOneWidget);
    expect(find.text('最密集日'), findsOneWidget);
    expect(find.text('记录更多内容后，这里会出现本周概览'), findsOneWidget);
    expect(
      find.text('继续记录几次情绪后，会自动汇总记录数、活跃天数和高峰时段。'),
      findsOneWidget,
    );
  });

  testWidgets('未登录时我的页顶部提供登录入口并跳转账号引导页', (tester) async {
    getIt.registerSingleton<OceanAccountService>(
      _FakeOceanAccountService(signedIn: false),
    );

    await tester.pumpWidget(
      _buildTestable(
        insightBloc: fakeInsightBloc,
        accountScreenBuilder: (_) =>
            const Scaffold(body: Center(child: Text('账号引导测试页'))),
      ),
    );
    await tester.pump();

    final loginButtonFinder = find.widgetWithText(TextButton, '登录');
    expect(loginButtonFinder, findsOneWidget);
    final loginButton = tester.widget<TextButton>(loginButtonFinder);
    expect(
      loginButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.accentLight,
    );
    expect(
      loginButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.textSecondary,
    );

    await tester.tap(loginButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('账号引导测试页'), findsOneWidget);
  });
}
