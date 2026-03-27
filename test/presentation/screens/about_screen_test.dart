import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindflow/core/di/injection.dart';
import 'package:mindflow/core/services/pro_subscription_service.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/screens/settings/about_screen.dart';

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

class _FakeProSubscriptionService extends Fake
    implements ProSubscriptionService {
  _FakeProSubscriptionService(this._database);

  final HiveDatabase _database;

  @override
  bool get debugMenuUnlocked =>
      _database.settingsBox.get('debug_menu_unlocked', defaultValue: false) ==
      true;

  @override
  bool get isDebugModeEnabled =>
      _database.settingsBox
          .get('app_debug_mode_enabled', defaultValue: false) ==
      true;

  @override
  Future<void> setDebugMenuUnlocked(bool value) async {
    await _database.settingsBox.put('debug_menu_unlocked', value);
  }

  @override
  Future<void> setDebugModeEnabled(bool value) async {
    await _database.settingsBox.put('app_debug_mode_enabled', value);
  }
}

Widget _buildAboutScreen() {
  return const CupertinoApp(
    locale: Locale('zh'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: AboutScreen(),
  );
}

void main() {
  late _FakeHiveDatabase fakeDb;

  setUp(() {
    fakeDb = _FakeHiveDatabase();
    getIt.reset();
    getIt.registerSingleton<HiveDatabase>(fakeDb);
    getIt.registerSingleton<ProSubscriptionService>(
      _FakeProSubscriptionService(fakeDb),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'AboutScreen hides onboarding switch until debug easter egg is unlocked',
      (
    tester,
  ) async {
    await tester.pumpWidget(_buildAboutScreen());
    await tester.pump();

    expect(find.text('每次展示新手引导'), findsNothing);
  });

  testWidgets(
      'AboutScreen shows and persists onboarding switch inside unlocked debug section',
      (
    tester,
  ) async {
    await fakeDb.settingsBox.put('debug_menu_unlocked', true);
    expect(
      fakeDb.settingsBox.get('debug_menu_unlocked', defaultValue: false),
      isTrue,
    );
    expect(getIt<ProSubscriptionService>().debugMenuUnlocked, isTrue);

    await tester.pumpWidget(_buildAboutScreen());
    await tester.pump();

    expect(find.text('每次展示新手引导'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSwitch).last);
    await tester.pump();

    expect(
      fakeDb.settingsBox.get('show_onboarding_always', defaultValue: false),
      isTrue,
    );
  });
}
