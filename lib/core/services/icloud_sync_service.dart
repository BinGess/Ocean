library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../data/datasources/local/hive_database.dart';
import '../../data/models/record_model.dart';
import '../../data/models/weekly_insight_model.dart';

class ICloudSyncService {
  static const String _channelName = 'mindflow/icloud_sync';
  static const String _enabledKey = 'icloud_sync_enabled';
  static const String _lastSyncedAtKey = 'icloud_sync_last_synced_at';
  static const String _backupFileName = 'mindflow_icloud_backup.json';
  static const int _backupVersion = 1;

  static const List<String> _settingsSyncPrefixes = [
    'daily_mood_',
    'daily_summary_',
  ];

  final HiveDatabase _database;
  final MethodChannel _channel = const MethodChannel(_channelName);

  StreamSubscription<BoxEvent>? _recordsSubscription;
  StreamSubscription<BoxEvent>? _weeklyInsightsSubscription;
  StreamSubscription<BoxEvent>? _insightReportsSubscription;
  StreamSubscription<BoxEvent>? _settingsSubscription;
  Timer? _debounceTimer;

  bool _isApplyingRemoteData = false;
  bool _isSyncing = false;
  String? _cachedContainerPath;

  ICloudSyncService({
    required HiveDatabase database,
  }) : _database = database;

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<void> init() async {
    _bindWatchers();
  }

  Future<bool> get isEnabled async =>
      _database.settingsBox.get(_enabledKey) as bool? ?? false;

  Future<bool> get isAvailable async => (await _getContainerPath()) != null;

  Future<DateTime?> get lastSyncedAt async =>
      _parseDateTime(_database.settingsBox.get(_lastSyncedAtKey) as String?);

  Future<ICloudBackupStatus> getBackupStatus() async {
    final containerPath = await _getContainerPath();
    if (containerPath == null) {
      return const ICloudBackupStatus(
        isAvailable: false,
        backupExists: false,
        fileName: _backupFileName,
      );
    }

    final file = File('$containerPath/$_backupFileName');
    if (!await file.exists()) {
      return const ICloudBackupStatus(
        isAvailable: true,
        backupExists: false,
        fileName: _backupFileName,
      );
    }

    final stat = await file.stat();
    final payload = await _readRemotePayload();
    final records = payload?['records'];
    final weeklyInsights = payload?['weekly_insights'];
    final insightReports = payload?['insight_reports'];

    return ICloudBackupStatus(
      isAvailable: true,
      backupExists: true,
      fileName: _backupFileName,
      fileSizeBytes: stat.size,
      exportedAt: _parseDateTime(payload?['exported_at'] as String?),
      recordCount: records is List ? records.length : 0,
      weeklyInsightCount: weeklyInsights is List ? weeklyInsights.length : 0,
      insightReportCount: insightReports is Map ? insightReports.length : 0,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await _database.settingsBox.put(_enabledKey, false);
      _debounceTimer?.cancel();
      return;
    }

    final containerPath = await _getContainerPath();
    if (containerPath == null) {
      throw StateError('iCloud container unavailable');
    }

    await _database.settingsBox.put(_enabledKey, true);

    final remotePayload = await _readRemotePayload();
    final hasLocalData = _hasAnySyncableLocalData();

    if (!hasLocalData && remotePayload != null) {
      await _applyRemotePayload(remotePayload);
      return;
    }

    await syncNow();
  }

  Future<void> initializeOnLaunch() async {
    if (!await isEnabled) return;
    await refreshFromCloudIfNeeded();
  }

  Future<void> refreshFromCloudIfNeeded() async {
    if (!await isEnabled) return;

    final remotePayload = await _readRemotePayload();
    if (remotePayload == null) {
      if (_hasAnySyncableLocalData()) {
        await syncNow();
      }
      return;
    }

    final remoteExportedAt =
        _parseDateTime(remotePayload['exported_at'] as String?);
    final localLastSyncedAt = await lastSyncedAt;
    final hasLocalData = _hasAnySyncableLocalData();

    final shouldImport = !hasLocalData ||
        (remoteExportedAt != null &&
            (localLastSyncedAt == null ||
                remoteExportedAt.isAfter(localLastSyncedAt)));

    if (shouldImport) {
      await _applyRemotePayload(remotePayload);
      return;
    }

    if (localLastSyncedAt == null && hasLocalData) {
      await syncNow();
    }
  }

  Future<void> syncNow() async {
    if (_isSyncing || _isApplyingRemoteData) return;
    if (!await isEnabled) return;

    final containerPath = await _getContainerPath();
    if (containerPath == null) return;

    _isSyncing = true;
    try {
      final payload = _buildBackupPayload();
      final file = File('$containerPath/$_backupFileName');
      await file.writeAsString(jsonEncode(payload));
      await _database.settingsBox.put(
        _lastSyncedAtKey,
        payload['exported_at'] as String,
      );
      debugPrint('ICloudSyncService: iCloud backup synced');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _recordsSubscription?.cancel();
    _weeklyInsightsSubscription?.cancel();
    _insightReportsSubscription?.cancel();
    _settingsSubscription?.cancel();
  }

  void _bindWatchers() {
    _recordsSubscription ??=
        _database.recordsBox.watch().listen((_) => _scheduleSync());
    _weeklyInsightsSubscription ??=
        _database.weeklyInsightsBox.watch().listen((_) => _scheduleSync());
    _insightReportsSubscription ??=
        _database.insightReportsBox.watch().listen((_) => _scheduleSync());
    _settingsSubscription ??= _database.settingsBox.watch().listen((event) {
      final key = event.key?.toString();
      if (key == null) return;
      if (key == _enabledKey || key == _lastSyncedAtKey) return;
      if (_isSyncableSettingKey(key)) {
        _scheduleSync();
      }
    });
  }

  void _scheduleSync() {
    if (_isApplyingRemoteData) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      if (!await isEnabled) return;
      await syncNow();
    });
  }

  Future<String?> _getContainerPath() async {
    if (!isSupportedPlatform) return null;
    if (_cachedContainerPath != null) return _cachedContainerPath;

    try {
      final path =
          await _channel.invokeMethod<String>('getICloudContainerPath');
      if (path == null || path.isEmpty) {
        return null;
      }
      _cachedContainerPath = path;
      return path;
    } catch (error) {
      debugPrint('ICloudSyncService: failed to resolve iCloud path: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readRemotePayload() async {
    final containerPath = await _getContainerPath();
    if (containerPath == null) return null;

    final file = File('$containerPath/$_backupFileName');
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (error) {
      debugPrint('ICloudSyncService: failed to read remote payload: $error');
    }

    return null;
  }

  Map<String, dynamic> _buildBackupPayload() {
    final exportedAt = DateTime.now().toIso8601String();

    return {
      'version': _backupVersion,
      'exported_at': exportedAt,
      'records': _database.recordsBox.values
          .map(_serializeRecordModel)
          .toList(growable: false),
      'weekly_insights': _database.weeklyInsightsBox.values
          .map(_serializeWeeklyInsightModel)
          .toList(growable: false),
      'insight_reports':
          Map<String, String>.from(_database.insightReportsBox.toMap()),
      'settings': _getSyncableSettingsEntries(),
    };
  }

  Future<void> _applyRemotePayload(Map<String, dynamic> payload) async {
    _isApplyingRemoteData = true;
    _debounceTimer?.cancel();

    try {
      await _applyRecords(payload['records']);
      await _applyWeeklyInsights(payload['weekly_insights']);
      await _applyInsightReports(payload['insight_reports']);
      await _applySettings(payload['settings']);

      final remoteExportedAt =
          _parseDateTime(payload['exported_at'] as String?) ?? DateTime.now();
      await _database.settingsBox.put(
        _lastSyncedAtKey,
        remoteExportedAt.toIso8601String(),
      );
      debugPrint('ICloudSyncService: restored data from iCloud');
    } finally {
      _isApplyingRemoteData = false;
    }
  }

  Future<void> _applyRecords(dynamic rawRecords) async {
    if (rawRecords is! List) return;

    for (final item in rawRecords) {
      if (item is! Map) continue;
      final map = _stringifyMap(item);
      final model = _deserializeRecordModel(map);
      if (model == null) continue;

      final local = _database.recordsBox.get(model.id);
      if (local == null || model.updatedAt.isAfter(local.updatedAt)) {
        await _database.recordsBox.put(model.id, model);
      }
    }
  }

  Future<void> _applyWeeklyInsights(dynamic rawInsights) async {
    if (rawInsights is! List) return;

    for (final item in rawInsights) {
      if (item is! Map) continue;
      final map = _stringifyMap(item);
      final model = _deserializeWeeklyInsightModel(map);
      if (model == null) continue;

      final local = _database.weeklyInsightsBox.get(model.id);
      if (local == null || model.updatedAt.isAfter(local.updatedAt)) {
        await _database.weeklyInsightsBox.put(model.id, model);
      }
    }
  }

  Future<void> _applyInsightReports(dynamic rawReports) async {
    if (rawReports is! Map) return;

    for (final entry in rawReports.entries) {
      final weekRange = entry.key.toString();
      final remoteRaw = entry.value?.toString();
      if (remoteRaw == null || remoteRaw.isEmpty) continue;

      final localRaw = _database.insightReportsBox.get(weekRange);
      final remoteCachedAt = _extractCacheTimestamp(remoteRaw);
      final localCachedAt = _extractCacheTimestamp(localRaw);

      if (localRaw == null ||
          remoteCachedAt == null ||
          localCachedAt == null ||
          remoteCachedAt.isAfter(localCachedAt)) {
        await _database.insightReportsBox.put(weekRange, remoteRaw);
      }
    }
  }

  Future<void> _applySettings(dynamic rawSettings) async {
    if (rawSettings is! Map) return;

    for (final entry in rawSettings.entries) {
      final key = entry.key.toString();
      if (!_isSyncableSettingKey(key)) continue;
      await _database.settingsBox.put(key, entry.value);
    }
  }

  bool _hasAnySyncableLocalData() {
    return _database.recordsBox.isNotEmpty ||
        _database.weeklyInsightsBox.isNotEmpty ||
        _database.insightReportsBox.isNotEmpty ||
        _getSyncableSettingsEntries().isNotEmpty;
  }

  Map<String, dynamic> _getSyncableSettingsEntries() {
    final entries = <String, dynamic>{};
    final source = _database.settingsBox.toMap();

    for (final entry in source.entries) {
      final key = entry.key?.toString();
      if (key == null) continue;
      if (_isSyncableSettingKey(key)) {
        entries[key] = entry.value;
      }
    }

    return entries;
  }

  bool _isSyncableSettingKey(String key) {
    return _settingsSyncPrefixes.any(key.startsWith);
  }

  Map<String, dynamic> _serializeRecordModel(RecordModel model) {
    return {
      'id': model.id,
      'type': model.type,
      'transcription': model.transcription,
      'created_at': model.createdAt.toIso8601String(),
      'updated_at': model.updatedAt.toIso8601String(),
      'audio_url': null,
      'duration': model.duration,
      'processing_mode': model.processingMode,
      'moods': model.moods,
      'needs': model.needs,
      'nvc': model.nvc,
    };
  }

  RecordModel? _deserializeRecordModel(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final type = json['type']?.toString();
    final transcription = json['transcription']?.toString();
    final createdAt = _parseDateTime(json['created_at']?.toString());
    final updatedAt = _parseDateTime(json['updated_at']?.toString());

    if (id == null ||
        type == null ||
        transcription == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return RecordModel(
      id: id,
      type: type,
      transcription: transcription,
      createdAt: createdAt,
      updatedAt: updatedAt,
      audioUrl: null,
      duration: _toDouble(json['duration']),
      processingMode: json['processing_mode']?.toString(),
      moods: _toStringList(json['moods']),
      needs: _toStringList(json['needs']),
      nvc: _mapOrNull(json['nvc']),
    );
  }

  Map<String, dynamic> _serializeWeeklyInsightModel(WeeklyInsightModel model) {
    return {
      'id': model.id,
      'week_range': model.weekRange,
      'start_date': model.startDate.toIso8601String(),
      'end_date': model.endDate.toIso8601String(),
      'emotional_patterns': model.emotionalPatterns,
      'micro_experiments': model.microExperiments,
      'need_statistics': model.needStatistics,
      'ai_summary': model.aiSummary,
      'referenced_records': model.referencedRecords,
      'created_at': model.createdAt.toIso8601String(),
      'updated_at': model.updatedAt.toIso8601String(),
    };
  }

  WeeklyInsightModel? _deserializeWeeklyInsightModel(
      Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final weekRange = json['week_range']?.toString();
    final startDate = _parseDateTime(json['start_date']?.toString());
    final endDate = _parseDateTime(json['end_date']?.toString());
    final createdAt = _parseDateTime(json['created_at']?.toString());
    final updatedAt = _parseDateTime(json['updated_at']?.toString());

    if (id == null ||
        weekRange == null ||
        startDate == null ||
        endDate == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return WeeklyInsightModel(
      id: id,
      weekRange: weekRange,
      startDate: startDate,
      endDate: endDate,
      emotionalPatterns: _toListOfMaps(json['emotional_patterns']),
      microExperiments: _toListOfMaps(json['micro_experiments']),
      needStatistics: _toListOfMaps(json['need_statistics']),
      aiSummary: json['ai_summary']?.toString(),
      referencedRecords: _toStringList(json['referenced_records']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  DateTime? _extractCacheTimestamp(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) return null;
      return _parseDateTime(decoded['cached_at']?.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<String>? _toStringList(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;
    return value.map((item) => item.toString()).toList(growable: false);
  }

  List<Map<String, dynamic>> _toListOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map(_stringifyMap).toList(growable: false);
  }

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is! Map) return null;
    return _stringifyMap(value);
  }

  Map<String, dynamic> _stringifyMap(Map input) {
    final result = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map) {
        result[key] = _stringifyMap(value);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map) {
            return _stringifyMap(item);
          }
          if (item is List) {
            return item.map((nested) {
              if (nested is Map) {
                return _stringifyMap(nested);
              }
              return nested;
            }).toList(growable: false);
          }
          return item;
        }).toList(growable: false);
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}

class ICloudBackupStatus {
  const ICloudBackupStatus({
    required this.isAvailable,
    required this.backupExists,
    required this.fileName,
    this.exportedAt,
    this.fileSizeBytes = 0,
    this.recordCount = 0,
    this.weeklyInsightCount = 0,
    this.insightReportCount = 0,
  });

  final bool isAvailable;
  final bool backupExists;
  final String fileName;
  final DateTime? exportedAt;
  final int fileSizeBytes;
  final int recordCount;
  final int weeklyInsightCount;
  final int insightReportCount;
}
