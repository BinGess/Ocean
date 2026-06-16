import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:hive/hive.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/core/services/ocean_record_ownership_service.dart';
import 'package:mindflow/core/services/pending_sync_tracker.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/data/models/record_model.dart';
import 'package:mindflow/data/repositories/record_repository_impl.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/domain/entities/record.dart';

void main() {
  test('createQuickNote uses server first when signed in and caches response',
      () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: true)
      ..createResponse = {
        'revision': '1',
        'data': {
          'id': 'server-record',
          'type': 'quick_note',
          'transcription': 'created on server',
          'createdAt': '2026-05-08T08:00:00.000Z',
          'updatedAt': '2026-05-08T08:01:00.000Z',
          'audioUrl': null,
        },
      };
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
    );

    final record = await repository.createQuickNote(
      transcription: 'created locally',
      audioUrl: '/private/local/audio.wav',
      createdAt: DateTime.utc(2026, 5, 8, 8),
    );

    expect(api.createdRecords.single['transcription'], 'created locally');
    expect(api.createdRecords.single['audioUrl'], isNull);
    expect(record.id, 'server-record');
    expect(record.transcription, 'created on server');
    expect(database.recordsBox.get('server-record')?.audioUrl, isNull);
  });

  test('createQuickNote remains local only when signed out', () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: false);
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
    );

    final record = await repository.createQuickNote(
      transcription: 'guest record',
      audioUrl: '/private/local/audio.wav',
      createdAt: DateTime.utc(2026, 5, 8, 8),
    );

    expect(api.createdRecords, isEmpty);
    expect(record.transcription, 'guest record');
    expect(database.recordsBox.get(record.id)?.audioUrl,
        '/private/local/audio.wav');
  });

  test('createQuickNote falls back to local cache when server create fails',
      () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: true)
      ..createError = Exception('server rejected nvc payload');
    final ownership = OceanRecordOwnershipService(database);
    await ownership.setActiveAccount('user@example.com');
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
      accountApi: _FakeAccountApi(accountKey: 'user@example.com'),
      ownershipService: ownership,
    );

    final record = await repository.createQuickNote(
      transcription: 'nvc record',
      processingMode: ProcessingMode.withNVC,
      moods: const ['焦虑'],
      needs: const ['支持'],
      nvc: _nvcAnalysis(),
      createdAt: DateTime.utc(2026, 5, 24, 8),
    );

    expect(api.createdRecords.single['processingMode'], 'with_nvc');
    expect(record.transcription, 'nvc record');
    expect(record.processingMode, ProcessingMode.withNVC);
    expect(record.nvc?.observation, '今天项目发布卡住了');
    expect(database.recordsBox.get(record.id)?.nvc, isNotNull);
    expect(
      ownership.isVisible(recordId: record.id, accountKey: 'user@example.com'),
      isTrue,
    );
  });

  test('failed server create marks the record as pending sync', () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: true)
      ..createError = Exception('server rejected');
    final ownership = OceanRecordOwnershipService(database);
    await ownership.setActiveAccount('user@example.com');
    final pending = PendingSyncTracker(database: database);
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
      accountApi: _FakeAccountApi(accountKey: 'user@example.com'),
      ownershipService: ownership,
      pendingSync: pending,
    );

    await repository.createQuickNote(
      transcription: 'stranded record',
      createdAt: DateTime.utc(2026, 5, 24, 8),
    );

    expect(pending.hasPending, isTrue);
  });

  test('successful server create does not mark the record as pending sync',
      () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: true)
      ..createResponse = {
        'data': {
          'id': 'server-1',
          'type': 'quick_note',
          'transcription': 'synced record',
          'createdAt': '2026-05-24T08:00:00.000Z',
          'updatedAt': '2026-05-24T08:00:00.000Z',
        },
      };
    final ownership = OceanRecordOwnershipService(database);
    await ownership.setActiveAccount('user@example.com');
    final pending = PendingSyncTracker(database: database);
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
      accountApi: _FakeAccountApi(accountKey: 'user@example.com'),
      ownershipService: ownership,
      pendingSync: pending,
    );

    await repository.createQuickNote(
      transcription: 'synced record',
      createdAt: DateTime.utc(2026, 5, 24, 8),
    );

    expect(pending.hasPending, isFalse);
  });

  test('createQuickNote falls back locally when server create stalls',
      () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: true)..stallCreate = true;
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
      serverCreateTimeout: const Duration(milliseconds: 1),
    );

    final record = await repository.createQuickNote(
      transcription: 'nvc record during slow network',
      processingMode: ProcessingMode.withNVC,
      nvc: _nvcAnalysis(),
      createdAt: DateTime.utc(2026, 5, 24, 8),
    );

    expect(record.transcription, 'nvc record during slow network');
    expect(record.processingMode, ProcessingMode.withNVC);
    expect(database.recordsBox.get(record.id), isNotNull);
  });

  test('updateRecord uses server first when signed in and refreshes cache',
      () async {
    final database = _FakeHiveDatabase();
    final api = _FakeRecordsApi(signedIn: true)
      ..updateResponse = {
        'revision': '2',
        'data': {
          'id': 'record-1',
          'type': 'quick_note',
          'transcription': 'updated on server',
          'createdAt': '2026-05-08T08:00:00.000Z',
          'updatedAt': '2026-05-08T09:00:00.000Z',
          'audioUrl': null,
        },
      };
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
    );

    final record = await repository.updateRecord(
      Record(
        id: 'record-1',
        type: RecordType.quickNote,
        transcription: 'updated locally',
        createdAt: DateTime.utc(2026, 5, 8, 8),
        updatedAt: DateTime.utc(2026, 5, 8, 9),
      ),
    );

    expect(api.updatedRecords.single.id, 'record-1');
    expect(
        api.updatedRecords.single.payload['transcription'], 'updated locally');
    expect(record.transcription, 'updated on server');
    expect(database.recordsBox.get('record-1')?.transcription,
        'updated on server');
  });

  test('deleteRecord uses server first when signed in and removes local cache',
      () async {
    final database = _FakeHiveDatabase();
    await database.recordsBox.put(
      'record-1',
      RecordModel.fromEntity(
        Record(
          id: 'record-1',
          type: RecordType.quickNote,
          transcription: 'cached',
          createdAt: DateTime.utc(2026, 5, 8, 8),
          updatedAt: DateTime.utc(2026, 5, 8, 8),
        ),
      ),
    );
    final api = _FakeRecordsApi(signedIn: true);
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: api,
    );

    await repository.deleteRecord('record-1');

    expect(api.deletedIds, ['record-1']);
    expect(database.recordsBox.get('record-1'), isNull);
  });

  test('signed-out local mode still shows cached account-owned records',
      () async {
    final database = _FakeHiveDatabase();
    final ownership = OceanRecordOwnershipService(database);
    await database.recordsBox.put(
      'record-1',
      RecordModel.fromEntity(
        Record(
          id: 'record-1',
          type: RecordType.quickNote,
          transcription: 'cached account data',
          createdAt: DateTime.utc(2026, 5, 8, 8),
          updatedAt: DateTime.utc(2026, 5, 8, 8),
        ),
      ),
    );
    await ownership.markAccount('record-1', 'user@example.com');
    await ownership.clearActiveAccount();
    final repository = RecordRepositoryImpl(
      database: database,
      recordsApi: _FakeRecordsApi(signedIn: false),
      ownershipService: ownership,
    );

    final records = await repository.getAllRecords();

    expect(records.map((record) => record.id), ['record-1']);
  });
}

class _FakeRecordsApi implements OceanRecordsApi {
  _FakeRecordsApi({required this.signedIn});

  final bool signedIn;
  final List<Map<String, dynamic>> createdRecords = [];
  final List<_UpdatedRecord> updatedRecords = [];
  final List<String> deletedIds = [];
  Map<String, dynamic> createResponse = const {};
  Map<String, dynamic> updateResponse = const {};
  Object? createError;
  bool stallCreate = false;

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<Map<String, dynamic>> createRecord(Map<String, dynamic> record) async {
    createdRecords.add(record);
    final error = createError;
    if (error != null) throw error;
    if (stallCreate) return Completer<Map<String, dynamic>>().future;
    return createResponse;
  }

  @override
  Future<Map<String, dynamic>> deleteRecord(String id) {
    deletedIds.add(id);
    return Future.value({
      'revision': '3',
      'data': {'id': id, 'deletedAt': '2026-05-08T10:00:00.000Z'},
    });
  }

  @override
  Future<Map<String, dynamic>> listRecords() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> updateRecord(
    String id,
    Map<String, dynamic> record,
  ) {
    updatedRecords.add(_UpdatedRecord(id, record));
    return Future.value(updateResponse);
  }
}

class _FakeAccountApi implements OceanAccountApi {
  _FakeAccountApi({required this.accountKey});

  final String accountKey;

  @override
  Future<String?> get currentAccountKey async => accountKey;

  @override
  Future<String?> get currentEmail async => accountKey;

  @override
  Future<String?> get currentPhone async => null;

  @override
  Future<String?> get currentUserId async => accountKey;

  @override
  Future<bool> get isSignedIn async => true;

  @override
  Future<OceanAuthTokens> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OceanAuthTokens> loginWithSms({
    required String phone,
    required String code,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() {
    throw UnimplementedError();
  }

  @override
  Future<OceanAuthTokens> register({
    required String email,
    required String password,
    String? nickname,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendSmsCode({required String phone}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAccount() {
    throw UnimplementedError();
  }
}

NVCAnalysis _nvcAnalysis() {
  return NVCAnalysis(
    observation: '今天项目发布卡住了',
    feelings: const [
      Feeling(feeling: '焦虑', intensity: IntensityLevel.high),
    ],
    needs: const [
      Need(need: '支持', reason: '希望有人一起定位问题'),
    ],
    request: '先把保存问题修好',
    insight: '你正在尝试把压力变成清晰的下一步。',
    analyzedAt: DateTime.utc(2026, 5, 24, 8, 5),
  );
}

class _UpdatedRecord {
  const _UpdatedRecord(this.id, this.payload);

  final String id;
  final Map<String, dynamic> payload;
}

class _FakeHiveDatabase extends Fake implements HiveDatabase {
  final _FakeRecordBox _recordsBox = _FakeRecordBox();
  final _FakeSettingsBox _settingsBox = _FakeSettingsBox();

  @override
  Box<RecordModel> get recordsBox => _recordsBox;

  @override
  Box<dynamic> get settingsBox => _settingsBox;
}

class _FakeRecordBox extends Fake implements Box<RecordModel> {
  final Map<String, RecordModel> _store = {};

  @override
  RecordModel? get(dynamic key, {RecordModel? defaultValue}) {
    return _store[key] ?? defaultValue;
  }

  @override
  Future<void> put(dynamic key, RecordModel value) async {
    _store[key as String] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _store.remove(key);
  }

  @override
  Iterable<RecordModel> get values => _store.values;
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
