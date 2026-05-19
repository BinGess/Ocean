import 'dart:convert';

import '../../data/datasources/local/hive_database.dart';
import '../../data/models/record_model.dart';
import '../../data/models/weekly_insight_model.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/entities/insight_report.dart';
import '../../domain/entities/record.dart';
import '../../domain/entities/weekly_insight.dart';
import '../network/ocean_api_client.dart';
import 'ocean_record_sync_mapper.dart';
import 'ocean_record_ownership_service.dart';

export '../network/ocean_api_client.dart' show OceanSyncApi;

class OceanSyncResult {
  const OceanSyncResult({
    this.accepted = 0,
    this.ignored = 0,
    this.recordsChanged = 0,
    this.profileChanged = 0,
    this.dailySummariesChanged = 0,
    this.dailyMoodsChanged = 0,
    this.insightReportsChanged = 0,
    this.weeklyInsightsChanged = 0,
    required this.cursor,
  });

  final int accepted;
  final int ignored;
  final int recordsChanged;
  final int profileChanged;
  final int dailySummariesChanged;
  final int dailyMoodsChanged;
  final int insightReportsChanged;
  final int weeklyInsightsChanged;
  final String cursor;

  int get totalChanged =>
      recordsChanged +
      profileChanged +
      dailySummariesChanged +
      dailyMoodsChanged +
      insightReportsChanged +
      weeklyInsightsChanged;
}

class OceanSyncUploadException implements Exception {
  const OceanSyncUploadException({
    required this.message,
    this.cause,
    this.failedItems = const [],
  });

  final String message;
  final Object? cause;
  final List<String> failedItems;

  @override
  String toString() {
    if (failedItems.isEmpty) return message;
    return '$message（失败项：${failedItems.join(', ')}）';
  }
}

abstract class OceanAccountSyncService {
  Future<OceanSyncResult> pushAllLocalData();
  Future<OceanSyncResult> restoreSnapshot();
}

class OceanLocalSyncData {
  const OceanLocalSyncData({
    this.profile,
    this.records = const [],
    this.deletedRecords = const [],
    this.dailySummaries = const [],
    this.dailyMoods = const [],
    this.insightReports = const [],
    this.weeklyInsights = const [],
  });

  final Map<String, dynamic>? profile;
  final List<Record> records;
  final List<Map<String, dynamic>> deletedRecords;
  final List<Map<String, dynamic>> dailySummaries;
  final List<Map<String, dynamic>> dailyMoods;
  final List<Map<String, dynamic>> insightReports;
  final List<Map<String, dynamic>> weeklyInsights;
}

abstract class OceanSyncDataStore {
  Future<OceanLocalSyncData> readAll();
  Future<void> clearAccountData();
  Future<void> upsertProfile(Map<String, dynamic> profile);
  Future<void> upsertRecord(Record record);
  Future<void> deleteRecord(String id);
  Future<void> upsertDailySummary(Map<String, dynamic> summary);
  Future<void> deleteDailySummary(String date);
  Future<void> upsertDailyMood(Map<String, dynamic> mood);
  Future<void> deleteDailyMood(String date);
  Future<void> upsertInsightReport(Map<String, dynamic> report);
  Future<void> deleteInsightReport(String periodType, String periodKey);
  Future<void> upsertWeeklyInsight(Map<String, dynamic> insight);
  Future<void> deleteWeeklyInsight(String id);
  Future<void> markRecordsSyncedToCurrentAccount(Iterable<String> recordIds);
  Future<void> markLocalDataSyncedToCurrentAccount(OceanLocalSyncData data);
  Future<void> clearSyncedTombstones();
}

class HiveOceanSyncDataStore implements OceanSyncDataStore {
  HiveOceanSyncDataStore(
    this._database, {
    OceanRecordOwnershipService? ownershipService,
    OceanAccountApi? accountApi,
  })  : _ownershipService = ownershipService,
        _accountApi = accountApi;

  static const _profileAvatarKey = 'profile_avatar';
  static const _profileNicknameKey = 'profile_nickname';
  static const _profileSignatureKey = 'profile_signature';
  static const _dailyMoodPrefix = 'daily_mood_';
  static const _dailySummaryPrefix = 'daily_summary_';
  static const _updatedAtPrefix = 'ocean_sync_updated_at';
  static const _deletedRecordPrefix = 'ocean_sync_deleted_record_';

  final HiveDatabase _database;
  final OceanRecordOwnershipService? _ownershipService;
  final OceanAccountApi? _accountApi;

  @override
  Future<OceanLocalSyncData> readAll() async {
    return OceanLocalSyncData(
      profile: await _readProfile(),
      records: await _readOwnedRecords(),
      deletedRecords: _readDeletedRecords(),
      dailySummaries: await _readDailySummaries(),
      dailyMoods: await _readDailyMoods(),
      insightReports: await _readInsightReports(),
      weeklyInsights: await _readWeeklyInsights(),
    );
  }

  @override
  Future<void> clearAccountData() async {
    // Snapshot restore is merge-based. Do not delete local records or local
    // generated data here; server tombstones are applied per entity instead.
  }

  Future<List<Record>> _readOwnedRecords() async {
    final accountKey = await _currentAccountKey();
    final ownership = _ownershipService;
    if (ownership == null) {
      return _database.recordsBox.values
          .map((model) => model.toEntity())
          .toList();
    }
    return _database.recordsBox.values
        .where((model) => ownership.isLocalOrCurrentAccount(
              recordId: model.id,
              accountKey: accountKey,
            ))
        .map((model) => model.toEntity())
        .toList();
  }

  Future<String?> _currentAccountKey() async {
    final accountApi = _accountApi;
    if (accountApi == null) return null;
    return await accountApi.currentAccountKey;
  }

  Future<bool> _isEntityVisible(String entityType, String entityId) async {
    return _isEntityVisibleSync(
      entityType,
      entityId,
      await _currentAccountKey(),
    );
  }

  bool _isEntityVisibleSync(
    String entityType,
    String entityId,
    String? accountKey,
  ) {
    final ownership = _ownershipService;
    if (ownership == null) return true;
    return ownership.isEntityVisible(
      entityType: entityType,
      entityId: entityId,
      accountKey: accountKey,
    );
  }

  Future<void> _markEntityAccount(String entityType, String entityId) async {
    final accountKey = await _currentAccountKey();
    if (accountKey == null || accountKey.isEmpty) return;
    await _ownershipService?.markEntityAccount(
        entityType, entityId, accountKey);
  }

  Future<void> _clearEntityOwner(String entityType, String entityId) async {
    await _ownershipService?.clearEntityOwner(entityType, entityId);
  }

  Future<Map<String, dynamic>?> _readProfile() async {
    if (!await _isEntityVisible('profile', 'me')) return null;
    final avatar = _database.settingsBox.get(_profileAvatarKey) as String?;
    final nickname = _database.settingsBox.get(_profileNicknameKey) as String?;
    final signature =
        _database.settingsBox.get(_profileSignatureKey) as String?;
    if (_isBlank(avatar) && _isBlank(nickname) && _isBlank(signature)) {
      return null;
    }
    return {
      'avatar': _emptyToNull(avatar),
      'nickname': _emptyToNull(nickname),
      'signature': _emptyToNull(signature),
      'clientUpdatedAt': await _ensureUpdatedAt('profile', 'me'),
    };
  }

  Future<List<Map<String, dynamic>>> _readDailySummaries() async {
    final results = <Map<String, dynamic>>[];
    final accountKey = await _currentAccountKey();
    for (final rawKey in _database.settingsBox.keys) {
      final key = rawKey.toString();
      if (!key.startsWith(_dailySummaryPrefix)) continue;
      final date = key.substring(_dailySummaryPrefix.length);
      if (!_isEntityVisibleSync(
        'daily_summary',
        date,
        accountKey,
      )) {
        continue;
      }
      final raw = _database.settingsBox.get(key);
      if (raw is! String || raw.isEmpty) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final summary = DailySummary.fromJson(json);
        results.add({
          'date': date,
          'moodWord': summary.moodWord,
          'oneSentence': summary.oneSentence,
          'score': summary.score,
          'recordCount': summary.recordCount,
          'generatedAt': summary.generatedAt.toUtc().toIso8601String(),
          'userOverridden': summary.userOverridden,
          'clientUpdatedAt':
              _readUpdatedAt('daily_summary', date, summary.generatedAt),
        });
      } catch (_) {
        // Ignore corrupt local cache entries.
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _readDailyMoods() async {
    final results = <Map<String, dynamic>>[];
    final accountKey = await _currentAccountKey();
    for (final rawKey in _database.settingsBox.keys) {
      final key = rawKey.toString();
      if (!key.startsWith(_dailyMoodPrefix)) continue;
      final date = key.substring(_dailyMoodPrefix.length);
      if (!_isEntityVisibleSync('daily_mood', date, accountKey)) continue;
      final imagePath = _database.settingsBox.get(key) as String?;
      if (_isBlank(imagePath)) continue;
      results.add({
        'date': date,
        'imagePath': imagePath,
        'clientUpdatedAt': await _ensureUpdatedAt('daily_mood', date),
      });
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _readInsightReports() async {
    final results = <Map<String, dynamic>>[];
    final accountKey = await _currentAccountKey();
    for (final rawKey in _database.insightReportsBox.keys) {
      final periodKey = rawKey.toString();
      if (!_isEntityVisibleSync('insight_report', periodKey, accountKey)) {
        continue;
      }
      final raw = _database.insightReportsBox.get(rawKey);
      if (raw == null || raw.isEmpty) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final cachedAt = DateTime.parse(data['cached_at'] as String);
        final report = Map<String, dynamic>.from(data['report'] as Map);
        final reportEntity = InsightReport.fromJson(report);
        results.add({
          'periodType': 'weekly',
          'periodKey': periodKey,
          'weekRange': reportEntity.weekRange,
          'cachedAt': cachedAt.toUtc().toIso8601String(),
          'recordCount': reportEntity.recordCount,
          'report': report,
          'clientUpdatedAt': cachedAt.toUtc().toIso8601String(),
        });
      } catch (_) {
        // Ignore corrupt report cache entries.
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _readWeeklyInsights() async {
    final accountKey = await _currentAccountKey();
    return _database.weeklyInsightsBox.values.where((model) {
      return _isEntityVisibleSync('weekly_insight', model.id, accountKey);
    }).map((model) {
      final insight = model.toEntity();
      return {
        'id': insight.id,
        'weekRange': insight.weekRange,
        'startDate': insight.startDate.toUtc().toIso8601String(),
        'endDate': insight.endDate.toUtc().toIso8601String(),
        'payload': insight.toJson(),
        'clientUpdatedAt': insight.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _readDeletedRecords() {
    final results = <Map<String, dynamic>>[];
    for (final rawKey in _database.settingsBox.keys) {
      final key = rawKey.toString();
      if (!key.startsWith(_deletedRecordPrefix)) continue;
      final raw = _database.settingsBox.get(key);
      if (raw is! String || raw.isEmpty) continue;
      try {
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        results.add(Map<String, dynamic>.from(payload));
      } catch (_) {
        // Ignore corrupt tombstones.
      }
    }
    return results;
  }

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async {
    await _putNullableString(_profileAvatarKey, profile['avatar']);
    await _putNullableString(_profileNicknameKey, profile['nickname']);
    await _putNullableString(_profileSignatureKey, profile['signature']);
    await _saveUpdatedAt(
      'profile',
      'me',
      profile['clientUpdatedAt']?.toString(),
    );
    await _markEntityAccount('profile', 'me');
  }

  @override
  Future<void> upsertRecord(Record record) async {
    await _database.recordsBox.put(record.id, RecordModel.fromEntity(record));
    final accountKey = await _accountApi?.currentAccountKey;
    if (accountKey != null && accountKey.isNotEmpty) {
      await _ownershipService?.markAccount(record.id, accountKey);
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    final ownership = _ownershipService;
    if (ownership != null && ownership.isLocal(id)) {
      return;
    }
    await _database.recordsBox.delete(id);
    await _database.settingsBox.delete('$_deletedRecordPrefix$id');
    await _ownershipService?.clearOwner(id);
  }

  @override
  Future<void> upsertDailySummary(Map<String, dynamic> summary) async {
    final date = summary['date']?.toString();
    if (_isBlank(date)) return;
    final dateKey = date!;
    final localJson = {
      'date': dateKey,
      'mood_word': summary['moodWord'],
      'one_sentence': summary['oneSentence'],
      'score': summary['score'],
      'record_count': summary['recordCount'],
      'generated_at': summary['generatedAt'],
      'user_overridden': summary['userOverridden'] ?? false,
    };
    await _database.settingsBox.put(
      '$_dailySummaryPrefix$dateKey',
      jsonEncode(localJson),
    );
    await _saveUpdatedAt(
      'daily_summary',
      dateKey,
      summary['clientUpdatedAt']?.toString(),
    );
    await _markEntityAccount('daily_summary', dateKey);
  }

  @override
  Future<void> deleteDailySummary(String date) async {
    if (_ownershipService?.isEntityLocal('daily_summary', date) ?? false) {
      return;
    }
    await _database.settingsBox.delete('$_dailySummaryPrefix$date');
    await _clearEntityOwner('daily_summary', date);
  }

  @override
  Future<void> upsertDailyMood(Map<String, dynamic> mood) async {
    final date = mood['date']?.toString();
    final imagePath = mood['imagePath']?.toString();
    if (_isBlank(date) || _isBlank(imagePath)) return;
    final dateKey = date!;
    await _database.settingsBox.put('$_dailyMoodPrefix$dateKey', imagePath);
    await _saveUpdatedAt(
        'daily_mood', dateKey, mood['clientUpdatedAt']?.toString());
    await _markEntityAccount('daily_mood', dateKey);
  }

  @override
  Future<void> deleteDailyMood(String date) async {
    if (_ownershipService?.isEntityLocal('daily_mood', date) ?? false) {
      return;
    }
    await _database.settingsBox.delete('$_dailyMoodPrefix$date');
    await _clearEntityOwner('daily_mood', date);
  }

  @override
  Future<void> upsertInsightReport(Map<String, dynamic> report) async {
    final periodKey = _readString(
      report,
      const ['periodKey', 'period_key', 'weekRange', 'week_range'],
    );
    if (_isBlank(periodKey)) return;
    final payload = _readMap(report['report'] ?? report['payload']) ??
        _extractTopLevelInsightReport(report);
    if (payload == null) return;
    final cachedAt = _readString(
          report,
          const [
            'cachedAt',
            'cached_at',
            'clientUpdatedAt',
            'client_updated_at'
          ],
        ) ??
        DateTime.now().toUtc().toIso8601String();
    final raw = {
      'cached_at': cachedAt,
      'report': payload,
    };
    await _database.insightReportsBox.put(periodKey!, jsonEncode(raw));
    await _saveUpdatedAt(
      'insight_report',
      periodKey,
      _readString(report, const ['clientUpdatedAt', 'client_updated_at']),
    );
    await _markEntityAccount('insight_report', periodKey);
  }

  @override
  Future<void> deleteInsightReport(String periodType, String periodKey) async {
    if (_ownershipService?.isEntityLocal('insight_report', periodKey) ??
        false) {
      return;
    }
    await _database.insightReportsBox.delete(periodKey);
    await _clearEntityOwner('insight_report', periodKey);
  }

  @override
  Future<void> upsertWeeklyInsight(Map<String, dynamic> insight) async {
    final id = insight['id']?.toString();
    final payload = insight['payload'];
    if (_isBlank(id) || payload is! Map) return;
    final json = Map<String, dynamic>.from(payload);
    json['id'] ??= id;
    json['week_range'] ??= insight['weekRange'];
    json['start_date'] ??= insight['startDate'];
    json['end_date'] ??= insight['endDate'];
    json['updated_at'] ??= insight['clientUpdatedAt'];
    final entity = WeeklyInsight.fromJson(json);
    await _database.weeklyInsightsBox
        .put(id, WeeklyInsightModel.fromEntity(entity));
    await _saveUpdatedAt(
      'weekly_insight',
      id!,
      insight['clientUpdatedAt']?.toString(),
    );
    await _markEntityAccount('weekly_insight', id);
  }

  @override
  Future<void> deleteWeeklyInsight(String id) async {
    if (_ownershipService?.isEntityLocal('weekly_insight', id) ?? false) {
      return;
    }
    await _database.weeklyInsightsBox.delete(id);
    await _clearEntityOwner('weekly_insight', id);
  }

  @override
  Future<void> clearSyncedTombstones() async {
    final keys = _database.settingsBox.keys
        .map((key) => key.toString())
        .where((key) => key.startsWith(_deletedRecordPrefix))
        .toList();
    for (final key in keys) {
      await _database.settingsBox.delete(key);
    }
  }

  @override
  Future<void> markRecordsSyncedToCurrentAccount(
    Iterable<String> recordIds,
  ) async {
    final accountKey = await _accountApi?.currentAccountKey;
    if (accountKey == null || accountKey.isEmpty) return;
    await _ownershipService?.markManyAccount(recordIds, accountKey);
  }

  @override
  Future<void> markLocalDataSyncedToCurrentAccount(
    OceanLocalSyncData data,
  ) async {
    final accountKey = await _accountApi?.currentAccountKey;
    final ownership = _ownershipService;
    if (accountKey == null || accountKey.isEmpty || ownership == null) return;

    if (data.profile != null) {
      await ownership.markEntityAccount('profile', 'me', accountKey);
    }
    await ownership.markManyAccount(
      data.records.map((record) => record.id),
      accountKey,
    );
    for (final summary in data.dailySummaries) {
      final date = summary['date']?.toString();
      if (!_isBlank(date)) {
        await ownership.markEntityAccount('daily_summary', date!, accountKey);
      }
    }
    for (final mood in data.dailyMoods) {
      final date = mood['date']?.toString();
      if (!_isBlank(date)) {
        await ownership.markEntityAccount('daily_mood', date!, accountKey);
      }
    }
    for (final report in data.insightReports) {
      final periodKey = report['periodKey']?.toString();
      if (!_isBlank(periodKey)) {
        await ownership.markEntityAccount(
          'insight_report',
          periodKey!,
          accountKey,
        );
      }
    }
    for (final insight in data.weeklyInsights) {
      final id = insight['id']?.toString();
      if (!_isBlank(id)) {
        await ownership.markEntityAccount('weekly_insight', id!, accountKey);
      }
    }
  }

  Future<void> _putNullableString(String key, Object? value) async {
    final normalized = _emptyToNull(value?.toString());
    if (normalized == null) {
      await _database.settingsBox.delete(key);
    } else {
      await _database.settingsBox.put(key, normalized);
    }
  }

  String _readUpdatedAt(
    String entityType,
    String entityId,
    DateTime fallback,
  ) {
    final existing = _database.settingsBox.get(
      _updatedAtKey(entityType, entityId),
    ) as String?;
    return existing ?? fallback.toUtc().toIso8601String();
  }

  Future<String> _ensureUpdatedAt(String entityType, String entityId) async {
    final key = _updatedAtKey(entityType, entityId);
    final existing = _database.settingsBox.get(key) as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final value = DateTime.now().toUtc().toIso8601String();
    await _database.settingsBox.put(key, value);
    return value;
  }

  Future<void> _saveUpdatedAt(
    String entityType,
    String entityId,
    String? value,
  ) async {
    if (value == null || value.isEmpty) return;
    await _database.settingsBox.put(_updatedAtKey(entityType, entityId), value);
  }

  String _updatedAtKey(String entityType, String entityId) {
    return '${_updatedAtPrefix}_${entityType}_$entityId';
  }

  bool _isBlank(Object? value) =>
      value == null || value.toString().trim().isEmpty;

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

abstract class OceanSyncStateStore {
  Future<String> readCursor();
  Future<void> saveCursor(String cursor);
}

class HiveOceanSyncStateStore implements OceanSyncStateStore {
  HiveOceanSyncStateStore(this._database);

  static const cursorKey = 'ocean_sync_cursor';

  final HiveDatabase _database;

  @override
  Future<String> readCursor() async {
    return _database.settingsBox.get(cursorKey, defaultValue: '0') as String;
  }

  @override
  Future<void> saveCursor(String cursor) async {
    await _database.settingsBox.put(cursorKey, cursor);
  }
}

class OceanSyncService implements OceanAccountSyncService {
  OceanSyncService({
    required OceanSyncApi api,
    required OceanSyncDataStore dataStore,
    required OceanSyncStateStore stateStore,
  })  : _api = api,
        _dataStore = dataStore,
        _stateStore = stateStore;

  final OceanSyncApi _api;
  final OceanSyncDataStore _dataStore;
  final OceanSyncStateStore _stateStore;

  Future<OceanSyncResult> pushLocalRecords() => pushAllLocalData();

  @override
  Future<OceanSyncResult> pushAllLocalData() async {
    final data = await _dataStore.readAll();
    final records = [
      ...data.records.map(OceanRecordSyncMapper.toServerRecord),
      ...data.deletedRecords,
    ];
    try {
      final response = await _api.pushData(
        profile: data.profile,
        records: records,
        dailySummaries: data.dailySummaries,
        dailyMoods: data.dailyMoods,
        insightReports: data.insightReports,
        weeklyInsights: data.weeklyInsights,
      );
      return _finishPush([response], syncedData: data);
    } catch (error) {
      return _pushLocalDataInSmallBatches(
        data: data,
        records: records,
        originalError: error,
      );
    }
  }

  @override
  Future<OceanSyncResult> restoreSnapshot() async {
    final response = await _api.getSnapshot();
    final counts = await _applySnapshot(response);
    final cursor = _readCursorFromResponse(response);
    await _stateStore.saveCursor(cursor);
    return OceanSyncResult(
      recordsChanged: counts.records,
      profileChanged: counts.profile,
      dailySummariesChanged: counts.dailySummaries,
      dailyMoodsChanged: counts.dailyMoods,
      insightReportsChanged: counts.insightReports,
      weeklyInsightsChanged: counts.weeklyInsights,
      cursor: cursor,
    );
  }

  Future<OceanSyncResult> pullChanges() async {
    final currentCursor = await _stateStore.readCursor();
    final response = await _api.pull(cursor: currentCursor);
    final counts = _EntityChangeCounts();
    final changes = response['changes'];
    if (changes is List) {
      for (final change in changes) {
        if (change is! Map) continue;
        final payload = change['payload'];
        if (payload is! Map) continue;
        final applied = await _applyEntity(
          change['entityType']?.toString(),
          Map<String, dynamic>.from(payload),
        );
        counts.add(applied);
      }
    }
    final cursor = _readCursorFromResponse(response);
    await _stateStore.saveCursor(cursor);
    return OceanSyncResult(
      recordsChanged: counts.records,
      profileChanged: counts.profile,
      dailySummariesChanged: counts.dailySummaries,
      dailyMoodsChanged: counts.dailyMoods,
      insightReportsChanged: counts.insightReports,
      weeklyInsightsChanged: counts.weeklyInsights,
      cursor: cursor,
    );
  }

  Future<_EntityChangeCounts> _applySnapshot(
      Map<String, dynamic> response) async {
    final counts = _EntityChangeCounts();
    final profile = response['profile'];
    if (profile is Map) {
      counts.add(
          await _applyEntity('profile', Map<String, dynamic>.from(profile)));
    }
    await _applyEntityList(counts, 'record', response['records']);
    await _applyEntityList(counts, 'daily_summary', response['dailySummaries']);
    await _applyEntityList(counts, 'daily_mood', response['dailyMoods']);
    await _applyEntityList(
        counts, 'insight_report', response['insightReports']);
    await _applyEntityList(
        counts, 'weekly_insight', response['weeklyInsights']);
    return counts;
  }

  Future<OceanSyncResult> _pushLocalDataInSmallBatches({
    required OceanLocalSyncData data,
    required List<Map<String, dynamic>> records,
    required Object originalError,
  }) async {
    final responses = <Map<String, dynamic>>[];
    final failedItems = <String>[];

    Future<void> pushItem(
      String label,
      Future<Map<String, dynamic>> Function() action,
    ) async {
      try {
        responses.add(await action());
      } catch (_) {
        failedItems.add(label);
      }
    }

    if (data.profile != null) {
      await pushItem(
        'profile',
        () => _api.pushData(profile: data.profile),
      );
    }
    for (final record in records) {
      await pushItem(
        'record:${record['id'] ?? 'unknown'}',
        () => _api.pushData(records: [record]),
      );
    }
    for (final summary in data.dailySummaries) {
      await pushItem(
        'dailySummary:${summary['date'] ?? 'unknown'}',
        () => _api.pushData(dailySummaries: [summary]),
      );
    }
    for (final mood in data.dailyMoods) {
      await pushItem(
        'dailyMood:${mood['date'] ?? 'unknown'}',
        () => _api.pushData(dailyMoods: [mood]),
      );
    }
    for (final report in data.insightReports) {
      await pushItem(
        'insightReport:${report['periodKey'] ?? 'unknown'}',
        () => _api.pushData(insightReports: [report]),
      );
    }
    for (final insight in data.weeklyInsights) {
      await pushItem(
        'weeklyInsight:${insight['id'] ?? 'unknown'}',
        () => _api.pushData(weeklyInsights: [insight]),
      );
    }

    if (failedItems.isNotEmpty) {
      throw OceanSyncUploadException(
        message: '本机数据上传未全部完成，请稍后重试',
        cause: originalError,
        failedItems: failedItems,
      );
    }
    if (responses.isEmpty) {
      throw OceanSyncUploadException(
        message: '本机数据上传失败，请稍后重试',
        cause: originalError,
      );
    }
    return _finishPush(
      responses,
      syncedData: data,
    );
  }

  Future<OceanSyncResult> _finishPush(
    List<Map<String, dynamic>> responses, {
    OceanLocalSyncData? syncedData,
  }) async {
    var accepted = 0;
    var ignored = 0;
    var cursor = '0';
    for (final response in responses) {
      accepted += _readInt(response['accepted']);
      ignored += _readInt(response['ignored']);
      cursor = _readCursorFromResponse(response);
    }
    await _stateStore.saveCursor(cursor);
    if (syncedData != null) {
      await _dataStore.markLocalDataSyncedToCurrentAccount(syncedData);
    }
    await _dataStore.clearSyncedTombstones();
    return OceanSyncResult(
      accepted: accepted,
      ignored: ignored,
      cursor: cursor,
    );
  }

  Future<void> _applyEntityList(
    _EntityChangeCounts counts,
    String entityType,
    Object? values,
  ) async {
    if (values is! List) return;
    for (final item in values) {
      if (item is! Map) continue;
      counts
          .add(await _applyEntity(entityType, Map<String, dynamic>.from(item)));
    }
  }

  Future<String?> _applyEntity(
    String? entityType,
    Map<String, dynamic> payload,
  ) async {
    switch (entityType) {
      case 'profile':
        await _dataStore.upsertProfile(payload);
        return 'profile';
      case 'record':
        final id = payload['id'] as String?;
        if (id == null || id.isEmpty) return null;
        if (payload['deletedAt'] != null) {
          await _dataStore.deleteRecord(id);
        } else {
          await _dataStore.upsertRecord(
            OceanRecordSyncMapper.fromServerRecord(payload),
          );
        }
        return 'record';
      case 'daily_summary':
        final date = payload['date']?.toString();
        if (date == null || date.isEmpty) return null;
        if (payload['deletedAt'] != null) {
          await _dataStore.deleteDailySummary(date);
        } else {
          await _dataStore.upsertDailySummary(payload);
        }
        return 'daily_summary';
      case 'daily_mood':
        final date = payload['date']?.toString();
        if (date == null || date.isEmpty) return null;
        if (payload['deletedAt'] != null) {
          await _dataStore.deleteDailyMood(date);
        } else {
          await _dataStore.upsertDailyMood(payload);
        }
        return 'daily_mood';
      case 'insight_report':
        final periodType =
            _readString(payload, const ['periodType', 'period_type']) ??
                'weekly';
        final periodKey = _readString(
          payload,
          const ['periodKey', 'period_key', 'weekRange', 'week_range'],
        );
        if (periodKey == null || periodKey.isEmpty) return null;
        if (payload['deletedAt'] != null) {
          await _dataStore.deleteInsightReport(periodType, periodKey);
        } else {
          await _dataStore.upsertInsightReport(payload);
        }
        return 'insight_report';
      case 'weekly_insight':
        final id = payload['id']?.toString();
        if (id == null || id.isEmpty) return null;
        if (payload['deletedAt'] != null) {
          await _dataStore.deleteWeeklyInsight(id);
        } else {
          await _dataStore.upsertWeeklyInsight(payload);
        }
        return 'weekly_insight';
    }
    return null;
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

class _EntityChangeCounts {
  int profile = 0;
  int records = 0;
  int dailySummaries = 0;
  int dailyMoods = 0;
  int insightReports = 0;
  int weeklyInsights = 0;

  void add(String? entityType) {
    switch (entityType) {
      case 'profile':
        profile += 1;
        break;
      case 'record':
        records += 1;
        break;
      case 'daily_summary':
        dailySummaries += 1;
        break;
      case 'daily_mood':
        dailyMoods += 1;
        break;
      case 'insight_report':
        insightReports += 1;
        break;
      case 'weekly_insight':
        weeklyInsights += 1;
        break;
    }
  }
}

String? _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    final value = data[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.trim().isEmpty) continue;
    return text;
  }
  return null;
}

Map<String, dynamic>? _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return null;
}

Map<String, dynamic>? _extractTopLevelInsightReport(Map<String, dynamic> item) {
  final hasInsightFields = item.containsKey('emotion_overview') ||
      item.containsKey('emotionOverview') ||
      item.containsKey('pattern_hypothesis') ||
      item.containsKey('patternHypothesis');
  if (!hasInsightFields) return null;
  return Map<String, dynamic>.from(item)
    ..remove('periodType')
    ..remove('period_type')
    ..remove('periodKey')
    ..remove('period_key')
    ..remove('cachedAt')
    ..remove('cached_at')
    ..remove('clientUpdatedAt')
    ..remove('client_updated_at');
}
