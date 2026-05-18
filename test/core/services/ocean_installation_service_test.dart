import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/core/services/ocean_installation_service.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/data/models/record_model.dart';
import 'package:mindflow/data/models/weekly_insight_model.dart';

void main() {
  test('clears persisted keychain tokens on a fresh local installation',
      () async {
    final database = _FakeHiveDatabase();
    final tokenStore = _FakeTokenStore(hasTokens: true);
    final service = OceanInstallationService(
      database: database,
      tokenStore: tokenStore,
    );

    await service.reconcileInstallState();

    expect(tokenStore.clearCount, 1);
    expect(
      database.settingsBox.get(OceanInstallationService.installMarkerKey),
      'true',
    );
  });

  test('keeps tokens when local app data proves this is an existing install',
      () async {
    final database = _FakeHiveDatabase();
    await database.settingsBox.put('onboarding_completed', true);
    final tokenStore = _FakeTokenStore(hasTokens: true);
    final service = OceanInstallationService(
      database: database,
      tokenStore: tokenStore,
    );

    await service.reconcileInstallState();

    expect(tokenStore.clearCount, 0);
    expect(
      database.settingsBox.get(OceanInstallationService.installMarkerKey),
      'true',
    );
  });
}

class _FakeTokenStore implements OceanTokenStore {
  _FakeTokenStore({required this.hasTokens});

  final bool hasTokens;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
  }

  @override
  Future<OceanAuthTokens?> readTokens() async {
    if (!hasTokens) return null;
    return const OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      email: 'user@example.com',
    );
  }

  @override
  Future<void> saveTokens(OceanAuthTokens tokens) async {}
}

class _FakeHiveDatabase extends Fake implements HiveDatabase {
  final _FakeRecordBox _recordsBox = _FakeRecordBox();
  final _FakeWeeklyInsightBox _weeklyInsightsBox = _FakeWeeklyInsightBox();
  final _FakeSettingsBox _settingsBox = _FakeSettingsBox();
  final _FakeStringBox _insightReportsBox = _FakeStringBox();

  @override
  Box<RecordModel> get recordsBox => _recordsBox;

  @override
  Box<WeeklyInsightModel> get weeklyInsightsBox => _weeklyInsightsBox;

  @override
  Box<dynamic> get settingsBox => _settingsBox;

  @override
  Box<String> get insightReportsBox => _insightReportsBox;
}

class _FakeRecordBox extends Fake implements Box<RecordModel> {
  @override
  int get length => 0;
}

class _FakeWeeklyInsightBox extends Fake implements Box<WeeklyInsightModel> {
  @override
  int get length => 0;
}

class _FakeStringBox extends Fake implements Box<String> {
  @override
  int get length => 0;
}

class _FakeSettingsBox extends Fake implements Box<dynamic> {
  final Map<String, dynamic> _store = {};

  @override
  int get length => _store.length;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _store.containsKey(key) ? _store[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key as String] = value;
  }
}
