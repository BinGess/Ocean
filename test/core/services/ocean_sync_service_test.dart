import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ocean_sync_service.dart';
import 'package:mindflow/domain/entities/record.dart';

void main() {
  test('pushAllLocalData uploads all local entity groups and saves cursor',
      () async {
    final api = _FakeOceanSyncApi();
    final stateStore = _MemorySyncStateStore();
    final dataStore = _MemorySyncDataStore(
      OceanLocalSyncData(
        profile: const {
          'avatar': '🌊',
          'nickname': 'Ocean',
          'signature': 'stay fluid',
          'clientUpdatedAt': '2026-05-07T13:39:00.000Z',
        },
        records: [
          Record(
            id: 'record-1',
            type: RecordType.quickNote,
            transcription: 'sync me',
            createdAt: DateTime.utc(2026, 5, 7, 13, 40),
            updatedAt: DateTime.utc(2026, 5, 7, 13, 41),
            audioUrl: '/local/audio.m4a',
          ),
        ],
        dailySummaries: const [
          {
            'date': '2026-05-07',
            'moodWord': '平静',
            'oneSentence': '今天比较稳定',
            'score': 6,
            'recordCount': 2,
            'generatedAt': '2026-05-07T13:42:00.000Z',
            'userOverridden': false,
            'clientUpdatedAt': '2026-05-07T13:42:00.000Z',
          },
        ],
        dailyMoods: const [
          {
            'date': '2026-05-07',
            'imagePath': 'assets/images/moods/calm.png',
            'clientUpdatedAt': '2026-05-07T13:43:00.000Z',
          },
        ],
        insightReports: const [
          {
            'periodType': 'weekly',
            'periodKey': '2026-05-04 ~ 2026-05-10',
            'weekRange': '2026-05-04 ~ 2026-05-10',
            'cachedAt': '2026-05-07T13:44:00.000Z',
            'recordCount': 3,
            'report': {'id': 'report-1'},
            'clientUpdatedAt': '2026-05-07T13:44:00.000Z',
          },
        ],
        weeklyInsights: const [
          {
            'id': 'weekly-1',
            'weekRange': '2026-05-04 ~ 2026-05-10',
            'startDate': '2026-05-04T00:00:00.000Z',
            'endDate': '2026-05-10T00:00:00.000Z',
            'payload': {'id': 'weekly-1'},
            'clientUpdatedAt': '2026-05-07T13:45:00.000Z',
          },
        ],
      ),
    );
    final service = OceanSyncService(
      api: api,
      dataStore: dataStore,
      stateStore: stateStore,
    );

    final result = await service.pushAllLocalData();

    expect(result.accepted, 6);
    expect(stateStore.cursor, '3');
    expect(api.pushedProfile?['nickname'], 'Ocean');
    expect(api.pushedRecords.single['id'], 'record-1');
    expect(api.pushedRecords.single['audioUrl'], isNull);
    expect(api.pushedDailySummaries.single['date'], '2026-05-07');
    expect(api.pushedDailyMoods.single['imagePath'], contains('calm'));
    expect(api.pushedInsightReports.single['periodType'], 'weekly');
    expect(api.pushedWeeklyInsights.single['id'], 'weekly-1');
  });

  test('pushAllLocalData falls back to small batches when bulk upload fails',
      () async {
    final api = _FakeOceanSyncApi()..failNextPush = Exception('bulk failed');
    final stateStore = _MemorySyncStateStore();
    final dataStore = _MemorySyncDataStore(
      OceanLocalSyncData(
        profile: const {
          'nickname': 'Ocean',
          'clientUpdatedAt': '2026-05-07T13:39:00.000Z',
        },
        records: [
          Record(
            id: 'local-record',
            type: RecordType.quickNote,
            transcription: 'device B local record',
            createdAt: DateTime.utc(2026, 5, 7, 13, 40),
            updatedAt: DateTime.utc(2026, 5, 7, 13, 41),
          ),
        ],
        dailySummaries: const [
          {
            'date': '2026-05-07',
            'moodWord': '平静',
            'oneSentence': '今天比较稳定',
            'score': 6,
            'recordCount': 1,
            'generatedAt': '2026-05-07T13:42:00.000Z',
            'userOverridden': false,
            'clientUpdatedAt': '2026-05-07T13:42:00.000Z',
          },
        ],
      ),
    );
    final service = OceanSyncService(
      api: api,
      dataStore: dataStore,
      stateStore: stateStore,
    );

    final result = await service.pushAllLocalData();

    expect(result.accepted, 3);
    expect(api.pushCallCount, 4);
    expect(api.pushedProfiles.length, 1);
    expect(api.pushedRecordBatches.single.single['id'], 'local-record');
    expect(api.pushedDailySummaryBatches.single.single['date'], '2026-05-07');
    expect(stateStore.cursor, '12');
    expect(dataStore.clearSyncedTombstonesCount, 1);
  });

  test(
      'pushAllLocalData reports partial small-batch failures without clearing tombstones',
      () async {
    final api = _FakeOceanSyncApi()
      ..failNextPush = Exception('bulk failed')
      ..failedRecordIds.add('bad-record');
    final stateStore = _MemorySyncStateStore();
    final dataStore = _MemorySyncDataStore(
      OceanLocalSyncData(
        records: [
          Record(
            id: 'ok-record',
            type: RecordType.quickNote,
            transcription: 'ok',
            createdAt: DateTime.utc(2026, 5, 7),
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
          Record(
            id: 'bad-record',
            type: RecordType.quickNote,
            transcription: 'bad',
            createdAt: DateTime.utc(2026, 5, 7),
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
        ],
      ),
    );
    final service = OceanSyncService(
      api: api,
      dataStore: dataStore,
      stateStore: stateStore,
    );

    await expectLater(
      service.pushAllLocalData(),
      throwsA(isA<OceanSyncUploadException>()),
    );

    expect(api.pushedRecordBatches.length, 1);
    expect(api.pushedRecordBatches.single.single['id'], 'ok-record');
    expect(stateStore.cursor, '0');
    expect(dataStore.clearSyncedTombstonesCount, 0);
  });

  test('restoreSnapshot upserts all server entities and saves snapshot cursor',
      () async {
    final api = _FakeOceanSyncApi()
      ..snapshot = {
        'cursor': '12',
        'profile': {
          'avatar': '🌊',
          'nickname': 'Ocean',
          'signature': 'stay fluid',
          'clientUpdatedAt': '2026-05-07T13:39:00.000Z',
        },
        'records': [
          {
            'id': 'server-record',
            'type': 'quick_note',
            'transcription': 'from server',
            'createdAt': '2026-05-07T13:40:00.000Z',
            'updatedAt': '2026-05-07T13:41:00.000Z',
            'audioUrl': null,
          }
        ],
        'dailySummaries': [
          {
            'date': '2026-05-07',
            'moodWord': '平静',
            'oneSentence': '今天比较稳定',
            'score': 6,
            'recordCount': 2,
            'generatedAt': '2026-05-07T13:42:00.000Z',
            'userOverridden': false,
            'clientUpdatedAt': '2026-05-07T13:42:00.000Z',
          },
        ],
        'dailyMoods': [
          {
            'date': '2026-05-07',
            'imagePath': 'assets/images/moods/calm.png',
            'clientUpdatedAt': '2026-05-07T13:43:00.000Z',
          },
        ],
        'insightReports': [
          {
            'periodType': 'weekly',
            'periodKey': '2026-05-04 ~ 2026-05-10',
            'weekRange': '2026-05-04 ~ 2026-05-10',
            'cachedAt': '2026-05-07T13:44:00.000Z',
            'recordCount': 3,
            'report': {'id': 'report-1'},
            'clientUpdatedAt': '2026-05-07T13:44:00.000Z',
          },
        ],
      };
    final stateStore = _MemorySyncStateStore();
    final dataStore = _MemorySyncDataStore(const OceanLocalSyncData());
    final service = OceanSyncService(
      api: api,
      dataStore: dataStore,
      stateStore: stateStore,
    );

    final result = await service.restoreSnapshot();

    expect(result.totalChanged, 5);
    expect(result.recordsChanged, 1);
    expect(result.dailySummariesChanged, 1);
    expect(result.dailyMoodsChanged, 1);
    expect(result.insightReportsChanged, 1);
    expect(stateStore.cursor, '12');
    expect(dataStore.profile?['nickname'], 'Ocean');
    expect(dataStore.records.single.id, 'server-record');
    expect(dataStore.dailySummaries.single['date'], '2026-05-07');
  });

  test('restoreSnapshot merges server snapshot without clearing local data',
      () async {
    final api = _FakeOceanSyncApi()
      ..snapshot = {
        'cursor': '20',
        'profile': {
          'avatar': '🌊',
          'nickname': 'Server User',
          'signature': 'from server',
          'clientUpdatedAt': '2026-05-08T08:00:00.000Z',
        },
        'records': [
          {
            'id': 'server-record',
            'type': 'quick_note',
            'transcription': 'from server',
            'createdAt': '2026-05-08T08:00:00.000Z',
            'updatedAt': '2026-05-08T08:00:00.000Z',
            'audioUrl': null,
          },
        ],
        'dailySummaries': const [],
        'dailyMoods': const [],
        'insightReports': const [],
        'weeklyInsights': const [],
      };
    final stateStore = _MemorySyncStateStore();
    final dataStore = _MemorySyncDataStore(
      OceanLocalSyncData(
        profile: const {'nickname': 'Stale User'},
        records: [
          Record(
            id: 'stale-record',
            type: RecordType.quickNote,
            transcription: 'stale',
            createdAt: DateTime.utc(2026, 5, 7),
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
        ],
        dailySummaries: const [
          {'date': '2026-05-07', 'moodWord': '旧总结'},
        ],
        dailyMoods: const [
          {'date': '2026-05-07', 'imagePath': 'old.png'},
        ],
        insightReports: const [
          {'periodType': 'weekly', 'periodKey': 'old-week', 'report': {}},
        ],
        weeklyInsights: const [
          {'id': 'old-weekly', 'payload': {}},
        ],
      ),
    );
    final service = OceanSyncService(
      api: api,
      dataStore: dataStore,
      stateStore: stateStore,
    );

    await service.restoreSnapshot();

    expect(dataStore.profile?['nickname'], 'Server User');
    expect(
      dataStore.records.map((item) => item.id),
      containsAll(['stale-record', 'server-record']),
    );
    expect(dataStore.dailySummaries.single['date'], '2026-05-07');
    expect(dataStore.dailyMoods.single['date'], '2026-05-07');
    expect(dataStore.insightReports.single['periodKey'], 'old-week');
    expect(dataStore.weeklyInsights.single['id'], 'old-weekly');
  });

  test('pullChanges applies tombstone deletes for records and daily moods',
      () async {
    final api = _FakeOceanSyncApi()
      ..pullResponse = {
        'cursor': '18',
        'changes': [
          {
            'entityType': 'record',
            'payload': {'id': 'record-1', 'deletedAt': '2026-05-07T14:00:00Z'},
          },
          {
            'entityType': 'daily_mood',
            'payload': {
              'date': '2026-05-07',
              'deletedAt': '2026-05-07T14:00:00Z'
            },
          },
        ],
      };
    final stateStore = _MemorySyncStateStore()..cursor = '12';
    final dataStore = _MemorySyncDataStore(
      OceanLocalSyncData(
        records: [
          Record(
            id: 'record-1',
            type: RecordType.quickNote,
            transcription: 'delete me',
            createdAt: DateTime.utc(2026, 5, 7),
            updatedAt: DateTime.utc(2026, 5, 7),
          ),
        ],
        dailyMoods: const [
          {'date': '2026-05-07', 'imagePath': 'assets/images/moods/calm.png'},
        ],
      ),
    );
    final service = OceanSyncService(
      api: api,
      dataStore: dataStore,
      stateStore: stateStore,
    );

    final result = await service.pullChanges();

    expect(result.totalChanged, 2);
    expect(stateStore.cursor, '18');
    expect(dataStore.records, isEmpty);
    expect(dataStore.dailyMoods, isEmpty);
  });
}

class _FakeOceanSyncApi implements OceanSyncApi {
  Map<String, dynamic>? pushedProfile;
  List<Map<String, dynamic>> pushedRecords = [];
  List<Map<String, dynamic>> pushedDailySummaries = [];
  List<Map<String, dynamic>> pushedDailyMoods = [];
  List<Map<String, dynamic>> pushedInsightReports = [];
  List<Map<String, dynamic>> pushedWeeklyInsights = [];
  final List<Map<String, dynamic>> pushedProfiles = [];
  final List<List<Map<String, dynamic>>> pushedRecordBatches = [];
  final List<List<Map<String, dynamic>>> pushedDailySummaryBatches = [];
  final Set<String> failedRecordIds = {};
  Object? failNextPush;
  int pushCallCount = 0;
  Map<String, dynamic> snapshot = const {'cursor': '0', 'records': []};
  Map<String, dynamic> pullResponse = const {'cursor': '0', 'changes': []};

  @override
  Future<Map<String, dynamic>> pushData({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>> records = const [],
    List<Map<String, dynamic>> dailySummaries = const [],
    List<Map<String, dynamic>> dailyMoods = const [],
    List<Map<String, dynamic>> insightReports = const [],
    List<Map<String, dynamic>> weeklyInsights = const [],
  }) async {
    pushCallCount += 1;
    final pendingError = failNextPush;
    if (pendingError != null) {
      failNextPush = null;
      throw pendingError;
    }
    if (records.any((record) => failedRecordIds.contains(record['id']))) {
      throw Exception('record rejected');
    }
    pushedProfile = profile;
    pushedRecords = records;
    pushedDailySummaries = dailySummaries;
    pushedDailyMoods = dailyMoods;
    pushedInsightReports = insightReports;
    pushedWeeklyInsights = weeklyInsights;
    if (profile != null) pushedProfiles.add(profile);
    if (records.isNotEmpty) pushedRecordBatches.add(records);
    if (dailySummaries.isNotEmpty) {
      pushedDailySummaryBatches.add(dailySummaries);
    }
    final accepted = [
      if (profile != null) profile,
      ...records,
      ...dailySummaries,
      ...dailyMoods,
      ...insightReports,
      ...weeklyInsights,
    ].length;
    final cursor = (pushCallCount * 3).toString();
    return {'accepted': accepted, 'ignored': 0, 'cursor': cursor};
  }

  @override
  Future<Map<String, dynamic>> pushRecords(
    List<Map<String, dynamic>> records,
  ) async {
    return pushData(records: records);
  }

  @override
  Future<Map<String, dynamic>> getSnapshot() async => snapshot;

  @override
  Future<Map<String, dynamic>> pull({required String cursor}) async {
    return pullResponse;
  }
}

class _MemorySyncDataStore implements OceanSyncDataStore {
  _MemorySyncDataStore(this.data)
      : profile = data.profile == null ? null : Map.of(data.profile!),
        records = [...data.records],
        dailySummaries = data.dailySummaries.map(Map.of).toList(),
        dailyMoods = data.dailyMoods.map(Map.of).toList(),
        insightReports = data.insightReports.map(Map.of).toList(),
        weeklyInsights = data.weeklyInsights.map(Map.of).toList();

  final OceanLocalSyncData data;
  Map<String, dynamic>? profile;
  final List<Record> records;
  final List<Map<String, dynamic>> dailySummaries;
  final List<Map<String, dynamic>> dailyMoods;
  final List<Map<String, dynamic>> insightReports;
  final List<Map<String, dynamic>> weeklyInsights;
  int clearSyncedTombstonesCount = 0;

  @override
  Future<OceanLocalSyncData> readAll() async {
    return OceanLocalSyncData(
      profile: profile,
      records: [...records],
      dailySummaries: dailySummaries.map(Map.of).toList(),
      dailyMoods: dailyMoods.map(Map.of).toList(),
      insightReports: insightReports.map(Map.of).toList(),
      weeklyInsights: weeklyInsights.map(Map.of).toList(),
    );
  }

  @override
  Future<void> clearAccountData() async {
    profile = null;
    records.clear();
    dailySummaries.clear();
    dailyMoods.clear();
    insightReports.clear();
    weeklyInsights.clear();
  }

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async {
    this.profile = Map.of(profile);
  }

  @override
  Future<void> upsertRecord(Record record) async {
    records.removeWhere((item) => item.id == record.id);
    records.add(record);
  }

  @override
  Future<void> deleteRecord(String id) async {
    records.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> upsertDailySummary(Map<String, dynamic> summary) async {
    dailySummaries.removeWhere((item) => item['date'] == summary['date']);
    dailySummaries.add(Map.of(summary));
  }

  @override
  Future<void> deleteDailySummary(String date) async {
    dailySummaries.removeWhere((item) => item['date'] == date);
  }

  @override
  Future<void> upsertDailyMood(Map<String, dynamic> mood) async {
    dailyMoods.removeWhere((item) => item['date'] == mood['date']);
    dailyMoods.add(Map.of(mood));
  }

  @override
  Future<void> deleteDailyMood(String date) async {
    dailyMoods.removeWhere((item) => item['date'] == date);
  }

  @override
  Future<void> upsertInsightReport(Map<String, dynamic> report) async {
    insightReports
        .removeWhere((item) => item['periodKey'] == report['periodKey']);
    insightReports.add(Map.of(report));
  }

  @override
  Future<void> deleteInsightReport(String periodType, String periodKey) async {
    insightReports.removeWhere((item) => item['periodKey'] == periodKey);
  }

  @override
  Future<void> upsertWeeklyInsight(Map<String, dynamic> insight) async {
    weeklyInsights.removeWhere((item) => item['id'] == insight['id']);
    weeklyInsights.add(Map.of(insight));
  }

  @override
  Future<void> deleteWeeklyInsight(String id) async {
    weeklyInsights.removeWhere((item) => item['id'] == id);
  }

  @override
  Future<void> clearSyncedTombstones() async {
    clearSyncedTombstonesCount += 1;
  }

  @override
  Future<void> markRecordsSyncedToCurrentAccount(
    Iterable<String> recordIds,
  ) async {}

  @override
  Future<void> markLocalDataSyncedToCurrentAccount(
    OceanLocalSyncData data,
  ) async {}
}

class _MemorySyncStateStore implements OceanSyncStateStore {
  String cursor = '0';

  @override
  Future<String> readCursor() async => cursor;

  @override
  Future<void> saveCursor(String cursor) async {
    this.cursor = cursor;
  }
}
