import '../../data/datasources/local/hive_database.dart';

/// 记录「写服务端失败、仅存在于本地、尚未同步」的记录 id。
///
/// server-first 创建/更新失败时打标；补推成功后清除。
/// 用于让启动 / 回前台时的自动补推只在「确有待同步数据」时触发，
/// 避免每次都全量重推。
class PendingSyncTracker {
  PendingSyncTracker({required this.database});

  final HiveDatabase database;

  static const _recordPrefix = 'ocean_pending_sync_record_';

  /// 一次性回填标记：老版本遗留的本地记录（没有 pending 标记）
  /// 在升级到本版本后，首次登录态启动时补推一次。
  static const _backfillDoneKey = 'ocean_pending_sync_backfill_v16_done';

  Future<void> markRecord(String id) {
    return database.settingsBox.put('$_recordPrefix$id', true);
  }

  Future<void> unmarkRecord(String id) {
    return database.settingsBox.delete('$_recordPrefix$id');
  }

  bool get hasPending {
    return database.settingsBox.keys
        .any((key) => key.toString().startsWith(_recordPrefix));
  }

  Future<void> clear() async {
    final keys = database.settingsBox.keys
        .map((key) => key.toString())
        .where((key) => key.startsWith(_recordPrefix))
        .toList(growable: false);
    for (final key in keys) {
      await database.settingsBox.delete(key);
    }
  }

  /// 是否需要执行一次性回填（仅首次）。
  bool get shouldRunBackfill {
    return database.settingsBox.get(_backfillDoneKey) != true;
  }

  Future<void> markBackfillDone() {
    return database.settingsBox.put(_backfillDoneKey, true);
  }
}
