import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ocean_sync_service.dart';
import 'package:mindflow/domain/entities/record.dart';

void main() {
  test('pushLocalRecords uploads local records and saves returned cursor',
      () async {
    final api = _FakeOceanSyncApi();
    final stateStore = _MemorySyncStateStore();
    final recordsStore = _MemoryRecordsStore([
      Record(
        id: 'record-1',
        type: RecordType.quickNote,
        transcription: 'sync me',
        createdAt: DateTime.utc(2026, 5, 7, 13, 40),
        updatedAt: DateTime.utc(2026, 5, 7, 13, 41),
        audioUrl: '/local/audio.m4a',
      ),
    ]);
    final service = OceanSyncService(
      api: api,
      recordsStore: recordsStore,
      stateStore: stateStore,
    );

    final result = await service.pushLocalRecords();

    expect(result.accepted, 1);
    expect(stateStore.cursor, '9');
    expect(api.pushedRecords.single['id'], 'record-1');
    expect(api.pushedRecords.single['audioUrl'], isNull);
  });

  test('restoreSnapshot upserts server records and saves snapshot cursor',
      () async {
    final api = _FakeOceanSyncApi()
      ..snapshot = {
        'cursor': '12',
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
      };
    final stateStore = _MemorySyncStateStore();
    final recordsStore = _MemoryRecordsStore([]);
    final service = OceanSyncService(
      api: api,
      recordsStore: recordsStore,
      stateStore: stateStore,
    );

    final result = await service.restoreSnapshot();

    expect(result.recordsChanged, 1);
    expect(stateStore.cursor, '12');
    expect(recordsStore.records.single.id, 'server-record');
    expect(recordsStore.records.single.transcription, 'from server');
  });
}

class _FakeOceanSyncApi implements OceanSyncApi {
  List<Map<String, dynamic>> pushedRecords = [];
  Map<String, dynamic> snapshot = const {'cursor': '0', 'records': []};

  @override
  Future<Map<String, dynamic>> pushRecords(
    List<Map<String, dynamic>> records,
  ) async {
    pushedRecords = records;
    return {'accepted': records.length, 'ignored': 0, 'cursor': '9'};
  }

  @override
  Future<Map<String, dynamic>> getSnapshot() async => snapshot;

  @override
  Future<Map<String, dynamic>> pull({required String cursor}) async {
    return {'cursor': cursor, 'changes': []};
  }
}

class _MemoryRecordsStore implements OceanRecordsStore {
  _MemoryRecordsStore(List<Record> records) : records = [...records];

  final List<Record> records;

  @override
  Future<List<Record>> getAllRecords() async => [...records];

  @override
  Future<void> upsertRecord(Record record) async {
    records.removeWhere((item) => item.id == record.id);
    records.add(record);
  }

  @override
  Future<void> deleteRecord(String id) async {
    records.removeWhere((item) => item.id == id);
  }
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
