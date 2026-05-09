import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mindflow/core/services/ocean_account_cache_service.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/data/models/record_model.dart';
import 'package:mindflow/data/models/weekly_insight_model.dart';

void main() {
  test('clearAccountCache removes account-scoped data and keeps app settings',
      () async {
    final database = _FakeHiveDatabase();
    await database.recordsBox.put('record-1', _recordModel('record-1'));
    await database.weeklyInsightsBox.put('weekly-1', _weeklyInsightModel());
    await database.insightReportsBox.put('week', '{}');
    await database.settingsBox.put('profile_nickname', 'Ocean');
    await database.settingsBox.put('daily_mood_2026-05-08', 'calm.png');
    await database.settingsBox.put('daily_summary_2026-05-08', '{}');
    await database.settingsBox.put('ocean_sync_cursor', '9');
    await database.settingsBox.put('ocean_sync_deleted_record_1', '{}');
    await database.settingsBox.put('locale_code', 'zh');
    await database.settingsBox.put('app_lock_enabled', true);

    await OceanAccountCacheService(database).clearAccountCache();

    expect(database.recordsBox.values, isEmpty);
    expect(database.weeklyInsightsBox.values, isEmpty);
    expect(database.insightReportsBox.values, isEmpty);
    expect(database.settingsBox.get('profile_nickname'), isNull);
    expect(database.settingsBox.get('daily_mood_2026-05-08'), isNull);
    expect(database.settingsBox.get('daily_summary_2026-05-08'), isNull);
    expect(database.settingsBox.get('ocean_sync_cursor'), isNull);
    expect(database.settingsBox.get('ocean_sync_deleted_record_1'), isNull);
    expect(database.settingsBox.get('locale_code'), 'zh');
    expect(database.settingsBox.get('app_lock_enabled'), true);
  });
}

RecordModel _recordModel(String id) {
  final now = DateTime.utc(2026, 5, 8);
  return RecordModel(
    id: id,
    type: 'quick_note',
    transcription: 'cached',
    createdAt: now,
    updatedAt: now,
  );
}

WeeklyInsightModel _weeklyInsightModel() {
  final now = DateTime.utc(2026, 5, 8);
  return WeeklyInsightModel(
    id: 'weekly-1',
    weekRange: '2026-05-04 ~ 2026-05-10',
    startDate: now,
    endDate: now,
    emotionalPatterns: const [],
    microExperiments: const [],
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeHiveDatabase extends Fake implements HiveDatabase {
  final _FakeRecordBox _recordsBox = _FakeRecordBox();
  final _FakeWeeklyInsightBox _weeklyInsightsBox = _FakeWeeklyInsightBox();
  final _FakeStringBox _insightReportsBox = _FakeStringBox();
  final _FakeSettingsBox _settingsBox = _FakeSettingsBox();

  @override
  Box<RecordModel> get recordsBox => _recordsBox;

  @override
  Box<WeeklyInsightModel> get weeklyInsightsBox => _weeklyInsightsBox;

  @override
  Box<String> get insightReportsBox => _insightReportsBox;

  @override
  Box<dynamic> get settingsBox => _settingsBox;
}

class _FakeRecordBox extends Fake implements Box<RecordModel> {
  final Map<String, RecordModel> _store = {};

  @override
  Iterable<RecordModel> get values => _store.values;

  @override
  Future<int> clear() async {
    final count = _store.length;
    _store.clear();
    return count;
  }

  @override
  Future<void> put(dynamic key, RecordModel value) async {
    _store[key as String] = value;
  }
}

class _FakeWeeklyInsightBox extends Fake implements Box<WeeklyInsightModel> {
  final Map<String, WeeklyInsightModel> _store = {};

  @override
  Iterable<WeeklyInsightModel> get values => _store.values;

  @override
  Future<int> clear() async {
    final count = _store.length;
    _store.clear();
    return count;
  }

  @override
  Future<void> put(dynamic key, WeeklyInsightModel value) async {
    _store[key as String] = value;
  }
}

class _FakeStringBox extends Fake implements Box<String> {
  final Map<String, String> _store = {};

  @override
  Iterable<String> get values => _store.values;

  @override
  Future<int> clear() async {
    final count = _store.length;
    _store.clear();
    return count;
  }

  @override
  Future<void> put(dynamic key, String value) async {
    _store[key as String] = value;
  }
}

class _FakeSettingsBox extends Fake implements Box<dynamic> {
  final Map<String, dynamic> _store = {};

  @override
  Iterable<dynamic> get keys => _store.keys;

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
