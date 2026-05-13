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
  Future<void> clearSyncedTombstones();
}

class HiveOceanSyncDataStore implements OceanSyncDataStore {
  HiveOceanSyncDataStore(this._database);

  static const _profileAvatarKey = 'profile_avatar';
  static const _profileNicknameKey = 'profile_nickname';
  static const _profileSignatureKey = 'profile_signature';
  static const _dailyMoodPrefix = 'daily_mood_';
  static const _dailySummaryPrefix = 'daily_summary_';
  static const _updatedAtPrefix = 'ocean_sync_updated_at';
  static const _deletedRecordPrefix = 'ocean_sync_deleted_record_';

  final HiveDatabase _database;

  @override
  Future<OceanLocalSyncData> readAll() async {
    return OceanLocalSyncData(
      profile: await _readProfile(),
      records:
          _database.recordsBox.values.map((model) => model.toEntity()).toList(),
      deletedRecords: _readDeletedRecords(),
      dailySummaries: _readDailySummaries(),
      dailyMoods: await _readDailyMoods(),
      insightReports: _readInsightReports(),
      weeklyInsights: _readWeeklyInsights(),
    );
  }

  @override
  Future<void> clearAccountData() async {
    await _database.recordsBox.clear();
    await _database.weeklyInsightsBox.clear();
    await _database.insightReportsBox.clear();

    final keys = _database.settingsBox.keys
        .map((key) => key.toString())
        .where(_isAccountScopedSetting)
        .toList();
    for (final key in keys) {
      await _database.settingsBox.delete(key);
    }
  }

  Future<Map<String, dynamic>?> _readProfile() async {
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

  List<Map<String, dynamic>> _readDailySummaries() {
    final results = <Map<String, dynamic>>[];
    for (final rawKey in _database.settingsBox.keys) {
      final key = rawKey.toString();
      if (!key.startsWith(_dailySummaryPrefix)) continue;
      final raw = _database.settingsBox.get(key);
      if (raw is! String || raw.isEmpty) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final summary = DailySummary.fromJson(json);
        results.add({
          'date': key.substring(_dailySummaryPrefix.length),
          'moodWord': summary.moodWord,
          'oneSentence': summary.oneSentence,
          'score': summary.score,
          'recordCount': summary.recordCount,
          'generatedAt': summary.generatedAt.toUtc().toIso8601String(),
          'userOverridden': summary.userOverridden,
          'clientUpdatedAt': _readUpdatedAt('daily_summary',
              key.substring(_dailySummaryPrefix.length), summary.generatedAt),
        });
      } catch (_) {
        // Ignore corrupt local cache entries.
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _readDailyMoods() async {
    final results = <Map<String, dynamic>>[];
    for (final rawKey in _database.settingsBox.keys) {
      final key = rawKey.toString();
      if (!key.startsWith(_dailyMoodPrefix)) continue;
      final imagePath = _database.settingsBox.get(key) as String?;
      if (_isBlank(imagePath)) continue;
      final date = key.substring(_dailyMoodPrefix.length);
      results.add({
        'date': date,
        'imagePath': imagePath,
        'clientUpdatedAt': await _ensureUpdatedAt('daily_mood', date),
      });
    }
    return results;
  }

  List<Map<String, dynamic>> _readInsightReports() {
    final results = <Map<String, dynamic>>[];
    for (final rawKey in _database.insightReportsBox.keys) {
      final periodKey = rawKey.toString();
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

  List<Map<String, dynamic>> _readWeeklyInsights() {
    return _database.weeklyInsightsBox.values.map((model) {
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
  }

  @override
  Future<void> upsertRecord(Record record) async {
    await _database.recordsBox.put(record.id, RecordModel.fromEntity(record));
  }

  @override
  Future<void> deleteRecord(String id) async {
    await _database.recordsBox.delete(id);
    await _database.settingsBox.delete('$_deletedRecordPrefix$id');
  }

  @override
  Future<void> upsertDailySummary(Map<String, dynamic> summary) async {
    final date = summary['date']?.toString();
    if (_isBlank(date)) return;
    final localJson = {
      'date': date,
      'mood_word': summary['moodWord'],
      'one_sentence': summary['oneSentence'],
      'score': summary['score'],
      'record_count': summary['recordCount'],
      'generated_at': summary['generatedAt'],
      'user_overridden': summary['userOverridden'] ?? false,
    };
    await _database.settingsBox.put(
      '$_dailySummaryPrefix$date',
      jsonEncode(localJson),
    );
    await _saveUpdatedAt(
      'daily_summary',
      date!,
      summary['clientUpdatedAt']?.toString(),
    );
  }

  @override
  Future<void> deleteDailySummary(String date) async {
    await _database.settingsBox.delete('$_dailySummaryPrefix$date');
  }

  @override
  Future<void> upsertDailyMood(Map<String, dynamic> mood) async {
    final date = mood['date']?.toString();
    final imagePath = mood['imagePath']?.toString();
    if (_isBlank(date) || _isBlank(imagePath)) return;
    await _database.settingsBox.put('$_dailyMoodPrefix$date', imagePath);
    await _saveUpdatedAt(
        'daily_mood', date!, mood['clientUpdatedAt']?.toString());
  }

  @override
  Future<void> deleteDailyMood(String date) async {
    await _database.settingsBox.delete('$_dailyMoodPrefix$date');
  }

  @override
  Future<void> upsertInsightReport(Map<String, dynamic> report) async {
    final periodKey = report['periodKey']?.toString();
    if (_isBlank(periodKey)) return;
    final payload = report['report'];
    if (payload is! Map) return;
    final raw = {
      'cached_at': report['cachedAt'],
      'report': Map<String, dynamic>.from(payload),
    };
    await _database.insightReportsBox.put(periodKey!, jsonEncode(raw));
    await _saveUpdatedAt(
      'insight_report',
      periodKey,
      report['clientUpdatedAt']?.toString(),
    );
  }

  @override
  Future<void> deleteInsightReport(String periodType, String periodKey) async {
    await _database.insightReportsBox.delete(periodKey);
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
  }

  @override
  Future<void> deleteWeeklyInsight(String id) async {
    await _database.weeklyInsightsBox.delete(id);
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

  bool _isAccountScopedSetting(String key) {
    return key == _profileAvatarKey ||
        key == _profileNicknameKey ||
        key == _profileSignatureKey ||
        key == HiveOceanSyncStateStore.cursorKey ||
        key.startsWith(_dailyMoodPrefix) ||
        key.startsWith(_dailySummaryPrefix) ||
        key.startsWith('${_updatedAtPrefix}_') ||
        key.startsWith(_deletedRecordPrefix);
  }

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
      return _finishPush([response]);
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
    await _dataStore.clearAccountData();
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
    return _finishPush(responses);
  }

  Future<OceanSyncResult> _finishPush(
    List<Map<String, dynamic>> responses,
  ) async {
    var accepted = 0;
    var ignored = 0;
    var cursor = '0';
    for (final response in responses) {
      accepted += _readInt(response['accepted']);
      ignored += _readInt(response['ignored']);
      cursor = _readCursorFromResponse(response);
    }
    await _stateStore.saveCursor(cursor);
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
        final periodType = payload['periodType']?.toString() ?? 'weekly';
        final periodKey = payload['periodKey']?.toString();
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
