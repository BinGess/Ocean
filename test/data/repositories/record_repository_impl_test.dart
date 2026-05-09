import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/data/models/record_model.dart';
import 'package:mindflow/data/repositories/record_repository_impl.dart';
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
}

class _FakeRecordsApi implements OceanRecordsApi {
  _FakeRecordsApi({required this.signedIn});

  final bool signedIn;
  final List<Map<String, dynamic>> createdRecords = [];
  final List<_UpdatedRecord> updatedRecords = [];
  final List<String> deletedIds = [];
  Map<String, dynamic> createResponse = const {};
  Map<String, dynamic> updateResponse = const {};

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<Map<String, dynamic>> createRecord(Map<String, dynamic> record) async {
    createdRecords.add(record);
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
