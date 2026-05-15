// 记录仓储实现
// 使用 Hive 进行本地存储

import 'dart:convert';
import '../../core/network/ocean_api_client.dart';
import '../../core/services/ocean_record_sync_mapper.dart';
import '../../core/services/ocean_record_ownership_service.dart';
import '../../domain/entities/record.dart';
import '../../domain/entities/nvc_analysis.dart';
import '../../domain/entities/day_aggregation.dart';
import '../../domain/repositories/record_repository.dart';
import '../datasources/local/hive_database.dart';
import '../models/record_model.dart';

class RecordRepositoryImpl implements RecordRepository {
  final HiveDatabase database;
  final OceanRecordsApi? recordsApi;
  final OceanAccountApi? accountApi;
  final OceanRecordOwnershipService? ownershipService;

  RecordRepositoryImpl({
    required this.database,
    this.recordsApi,
    this.accountApi,
    this.ownershipService,
  });

  @override
  Future<Record> createQuickNote({
    required String transcription,
    String? audioUrl,
    double? duration,
    ProcessingMode? processingMode,
    List<String>? moods,
    List<String>? needs,
    NVCAnalysis? nvc,
    DateTime? createdAt,
  }) async {
    final recordTime = createdAt ?? DateTime.now();
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: RecordType.quickNote,
      transcription: transcription,
      createdAt: recordTime,
      updatedAt: recordTime,
      audioUrl: audioUrl,
      duration: duration,
      processingMode: processingMode,
      moods: moods,
      needs: needs,
      nvc: nvc,
    );
    return await _createRecord(record);
  }

  @override
  Future<Record> createJournal({
    required String transcription,
    String? title,
    String? summary,
    List<String>? referencedFragments,
  }) async {
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: RecordType.journal,
      transcription: transcription,
      title: title,
      summary: summary,
      referencedFragments: referencedFragments,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _createRecord(record);
  }

  @override
  Future<Record> createWeeklyRecord({
    required String transcription,
    required String weekRange,
    List<String>? referencedRecords,
  }) async {
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: RecordType.weekly,
      transcription: transcription,
      weekRange: weekRange,
      referencedRecords: referencedRecords,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _createRecord(record);
  }

  @override
  Future<List<Record>> getRecordsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getRecordsByDateRange(startOfDay, endOfDay);
  }

  @override
  Future<DayAggregation?> getDayAggregation(String dayKey) async {
    // TODO: 实现日聚合逻辑
    return null;
  }

  @override
  Future<List<DayAggregation>> getDayAggregations(
      DateTime start, DateTime end) async {
    // TODO: 实现日聚合列表
    return [];
  }

  @override
  Future<Record> updateProcessingMode(String id, ProcessingMode mode) async {
    final record = await getRecordById(id);
    if (record == null) throw Exception('Record not found');

    final updated = Record(
      id: record.id,
      type: record.type,
      transcription: record.transcription,
      createdAt: record.createdAt,
      updatedAt: DateTime.now(),
      processingMode: mode,
      audioUrl: record.audioUrl,
      duration: record.duration,
      moods: record.moods,
      needs: record.needs,
      nvc: record.nvc,
      title: record.title,
      summary: record.summary,
    );

    return await updateRecord(updated);
  }

  @override
  Future<Record> updateNVCAnalysis(String id, dynamic nvcAnalysis) async {
    final record = await getRecordById(id);
    if (record == null) throw Exception('Record not found');

    final updated = Record(
      id: record.id,
      type: record.type,
      transcription: record.transcription,
      createdAt: record.createdAt,
      updatedAt: DateTime.now(),
      nvc: nvcAnalysis as NVCAnalysis?,
      audioUrl: record.audioUrl,
      duration: record.duration,
      processingMode: record.processingMode,
      moods: record.moods,
      needs: record.needs,
      title: record.title,
      summary: record.summary,
    );

    return await updateRecord(updated);
  }

  @override
  Future<List<Record>> getRecentRecords({int limit = 10}) async {
    final allRecords = await getAllRecords();
    allRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allRecords.take(limit).toList();
  }

  Future<Record> _createRecord(Record record) async {
    if (await _isServerFirstEnabled()) {
      final response = await recordsApi!.createRecord(
        OceanRecordSyncMapper.toServerRecord(record),
      );
      final serverRecord = _recordFromResponse(response);
      await _cacheRecord(serverRecord, markCurrentAccount: true);
      return serverRecord;
    }

    final model = RecordModel.fromEntity(record);
    await database.recordsBox.put(record.id, model);
    await ownershipService?.markLocal(record.id);
    return model.toEntity();
  }

  @override
  Future<Record?> getRecordById(String id) async {
    final model = database.recordsBox.get(id);
    if (model == null) return null;
    final ownership = ownershipService;
    if (ownership != null &&
        !ownership.isVisible(
          recordId: id,
          accountKey: await _currentAccountKeyIfSignedIn(),
        )) {
      return null;
    }
    return model.toEntity();
  }

  @override
  Future<List<Record>> getAllRecords() async {
    if (await _isServerFirstEnabled()) {
      try {
        final response = await recordsApi!.listRecords();
        final data = response['data'];
        if (data is List) {
          final records = <Record>[];
          final serverRecordIds = <String>{};
          for (final item in data) {
            if (item is! Map) continue;
            final record = OceanRecordSyncMapper.fromServerRecord(
              Map<String, dynamic>.from(item),
            );
            await _cacheRecord(record, markCurrentAccount: true);
            records.add(record);
            serverRecordIds.add(record.id);
          }
          records.addAll(
            await _localRecordsForCurrentView(
              includeOnlyLocal: true,
              excludeIds: serverRecordIds,
            ),
          );
          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return records;
        }
      } catch (_) {
        final records = await _localRecordsForCurrentView();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      }
    }

    final models = await _visibleModels();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Record>> getRecordsByType(RecordType type) async {
    final typeString = type.toString().split('.').last;
    final models =
        (await _visibleModels()).where((m) => m.type == typeString).toList();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Record>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final models = (await _visibleModels())
        .where((m) =>
            // 使用包含边界的比较：>= start && <= end
            !m.createdAt.isBefore(start) && !m.createdAt.isAfter(end))
        .toList();

    // 按创建时间降序排序
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return models.map((m) => m.toEntity()).toList();
  }

  Future<List<Record>> getRecordsForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getRecordsByDateRange(startOfDay, endOfDay);
  }

  Future<List<Record>> getRecordsForWeek(DateTime weekStart) async {
    final endOfWeek = weekStart.add(const Duration(days: 7));
    return getRecordsByDateRange(weekStart, endOfWeek);
  }

  @override
  Future<Record> updateRecord(Record record) async {
    if (await _isServerFirstEnabled()) {
      final response = await recordsApi!.updateRecord(
        record.id,
        OceanRecordSyncMapper.toServerRecord(record),
      );
      final serverRecord = _recordFromResponse(response);
      await _cacheRecord(serverRecord, markCurrentAccount: true);
      return serverRecord;
    }

    final model = RecordModel.fromEntity(record);
    await database.recordsBox.put(record.id, model);
    await ownershipService?.markLocal(record.id);
    return model.toEntity();
  }

  @override
  Future<void> deleteRecord(String id) async {
    if (await _isServerFirstEnabled()) {
      await recordsApi!.deleteRecord(id);
      await database.recordsBox.delete(id);
      await database.settingsBox.delete('ocean_sync_deleted_record_$id');
      await ownershipService?.clearOwner(id);
      return;
    }

    final model = database.recordsBox.get(id);
    if (model != null) {
      final record = model.toEntity();
      final deletedAt = DateTime.now().toUtc();
      await database.settingsBox.put(
        'ocean_sync_deleted_record_$id',
        jsonEncode({
          'id': record.id,
          'type': _recordTypeToApi(record.type),
          'transcription': record.transcription,
          'createdAt': record.createdAt.toUtc().toIso8601String(),
          'updatedAt': deletedAt.toIso8601String(),
          'audioUrl': null,
          'duration': record.duration,
          'processingMode': record.processingMode == null
              ? null
              : _processingModeToApi(record.processingMode!),
          'moods': record.moods,
          'needs': record.needs,
          'nvc': record.nvc?.toJson(),
          'title': record.title,
          'summary': record.summary,
          'date': record.date,
          'referencedFragments': record.referencedFragments,
          'weekRange': record.weekRange,
          'referencedRecords': record.referencedRecords,
          'patternFeedback': record.patternFeedback,
          'deletedAt': deletedAt.toIso8601String(),
        }),
      );
    }
    await database.recordsBox.delete(id);
    await ownershipService?.clearOwner(id);
  }

  Future<bool> _isServerFirstEnabled() async {
    final api = recordsApi;
    return api != null && await api.isSignedIn;
  }

  Record _recordFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const OceanApiException('Invalid record response');
    }
    return OceanRecordSyncMapper.fromServerRecord(
      Map<String, dynamic>.from(data),
    );
  }

  Future<void> _cacheRecord(
    Record record, {
    bool markCurrentAccount = false,
  }) async {
    await database.recordsBox.put(record.id, RecordModel.fromEntity(record));
    if (!markCurrentAccount) return;
    final accountKey = await _currentAccountKey();
    if (accountKey != null && accountKey.isNotEmpty) {
      await ownershipService?.markAccount(record.id, accountKey);
    }
  }

  Future<List<RecordModel>> _visibleModels() async {
    final accountKey = await _currentAccountKeyIfSignedIn();
    final ownership = ownershipService;
    if (ownership == null) return database.recordsBox.values.toList();
    return database.recordsBox.values
        .where((model) => ownership.isVisible(
              recordId: model.id,
              accountKey: accountKey,
            ))
        .toList();
  }

  Future<List<Record>> _localRecordsForCurrentView({
    bool includeOnlyLocal = false,
    Set<String> excludeIds = const {},
  }) async {
    final accountKey = await _currentAccountKeyIfSignedIn();
    final ownership = ownershipService;
    final models = database.recordsBox.values.where((model) {
      if (excludeIds.contains(model.id)) return false;
      if (ownership == null) return true;
      if (includeOnlyLocal) return ownership.isLocal(model.id);
      return ownership.isVisible(recordId: model.id, accountKey: accountKey);
    }).toList();
    return models.map((model) => model.toEntity()).toList();
  }

  Future<String?> _currentAccountKeyIfSignedIn() async {
    if (!await _isServerFirstEnabled()) return null;
    return _currentAccountKey();
  }

  Future<String?> _currentAccountKey() async {
    final api = accountApi ??
        (recordsApi is OceanAccountApi ? recordsApi as OceanAccountApi : null);
    return api?.currentAccountKey;
  }

  String _recordTypeToApi(RecordType type) {
    switch (type) {
      case RecordType.quickNote:
        return 'quick_note';
      case RecordType.journal:
        return 'journal';
      case RecordType.weekly:
        return 'weekly';
    }
  }

  String _processingModeToApi(ProcessingMode mode) {
    switch (mode) {
      case ProcessingMode.onlyRecord:
        return 'only_record';
      case ProcessingMode.withMood:
        return 'with_mood';
      case ProcessingMode.withNVC:
        return 'with_nvc';
    }
  }

  Future<int> getRecordsCount() async {
    return database.recordsBox.length;
  }

  @override
  Future<List<Record>> searchRecords(String query) async {
    final lowerQuery = query.toLowerCase();
    final models = (await _visibleModels())
        .where((m) => m.transcription.toLowerCase().contains(lowerQuery))
        .toList();

    return models.map((m) => m.toEntity()).toList();
  }
}
