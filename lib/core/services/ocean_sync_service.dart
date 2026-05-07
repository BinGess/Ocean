import '../../data/datasources/local/hive_database.dart';
import '../../data/models/record_model.dart';
import '../../domain/entities/record.dart';
import '../network/ocean_api_client.dart';
import 'ocean_record_sync_mapper.dart';

export '../network/ocean_api_client.dart' show OceanSyncApi;

class OceanSyncResult {
  const OceanSyncResult({
    this.accepted = 0,
    this.ignored = 0,
    this.recordsChanged = 0,
    required this.cursor,
  });

  final int accepted;
  final int ignored;
  final int recordsChanged;
  final String cursor;
}

abstract class OceanRecordsStore {
  Future<List<Record>> getAllRecords();
  Future<void> upsertRecord(Record record);
  Future<void> deleteRecord(String id);
}

class HiveOceanRecordsStore implements OceanRecordsStore {
  HiveOceanRecordsStore(this._database);

  final HiveDatabase _database;

  @override
  Future<List<Record>> getAllRecords() async {
    return _database.recordsBox.values
        .map((model) => model.toEntity())
        .toList();
  }

  @override
  Future<void> upsertRecord(Record record) async {
    await _database.recordsBox.put(record.id, RecordModel.fromEntity(record));
  }

  @override
  Future<void> deleteRecord(String id) async {
    await _database.recordsBox.delete(id);
  }
}

abstract class OceanSyncStateStore {
  Future<String> readCursor();
  Future<void> saveCursor(String cursor);
}

class HiveOceanSyncStateStore implements OceanSyncStateStore {
  HiveOceanSyncStateStore(this._database);

  static const _cursorKey = 'ocean_sync_cursor';

  final HiveDatabase _database;

  @override
  Future<String> readCursor() async {
    return _database.settingsBox.get(_cursorKey, defaultValue: '0') as String;
  }

  @override
  Future<void> saveCursor(String cursor) async {
    await _database.settingsBox.put(_cursorKey, cursor);
  }
}

class OceanSyncService {
  OceanSyncService({
    required OceanSyncApi api,
    required OceanRecordsStore recordsStore,
    required OceanSyncStateStore stateStore,
  })  : _api = api,
        _recordsStore = recordsStore,
        _stateStore = stateStore;

  final OceanSyncApi _api;
  final OceanRecordsStore _recordsStore;
  final OceanSyncStateStore _stateStore;

  Future<OceanSyncResult> pushLocalRecords() async {
    final records = await _recordsStore.getAllRecords();
    final response = await _api.pushRecords(
      records.map(OceanRecordSyncMapper.toServerRecord).toList(),
    );
    final cursor = _readCursorFromResponse(response);
    await _stateStore.saveCursor(cursor);
    return OceanSyncResult(
      accepted: _readInt(response['accepted']),
      ignored: _readInt(response['ignored']),
      cursor: cursor,
    );
  }

  Future<OceanSyncResult> restoreSnapshot() async {
    final response = await _api.getSnapshot();
    final records = response['records'];
    var changed = 0;
    if (records is List) {
      for (final item in records) {
        if (item is! Map) continue;
        final payload = Map<String, dynamic>.from(item);
        if (payload['deletedAt'] != null) continue;
        await _recordsStore.upsertRecord(
          OceanRecordSyncMapper.fromServerRecord(payload),
        );
        changed += 1;
      }
    }
    final cursor = _readCursorFromResponse(response);
    await _stateStore.saveCursor(cursor);
    return OceanSyncResult(recordsChanged: changed, cursor: cursor);
  }

  Future<OceanSyncResult> pullChanges() async {
    final currentCursor = await _stateStore.readCursor();
    final response = await _api.pull(cursor: currentCursor);
    final changes = response['changes'];
    var changed = 0;
    if (changes is List) {
      for (final change in changes) {
        if (change is! Map || change['entityType'] != 'record') continue;
        final payload = change['payload'];
        if (payload is! Map) continue;
        final recordPayload = Map<String, dynamic>.from(payload);
        final id = recordPayload['id'] as String?;
        if (id == null || id.isEmpty) continue;
        if (recordPayload['deletedAt'] != null) {
          await _recordsStore.deleteRecord(id);
        } else {
          await _recordsStore.upsertRecord(
            OceanRecordSyncMapper.fromServerRecord(recordPayload),
          );
        }
        changed += 1;
      }
    }
    final cursor = _readCursorFromResponse(response);
    await _stateStore.saveCursor(cursor);
    return OceanSyncResult(recordsChanged: changed, cursor: cursor);
  }

  String _readCursorFromResponse(Map<String, dynamic> response) {
    return response['cursor']?.toString() ?? '0';
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
