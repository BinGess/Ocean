import '../../data/datasources/local/hive_database.dart';
import 'ocean_sync_service.dart';

class OceanAccountCacheService {
  OceanAccountCacheService(this._database);

  final HiveDatabase _database;

  Future<void> clearAccountCache() async {
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

  bool _isAccountScopedSetting(String key) {
    return key == 'profile_avatar' ||
        key == 'profile_nickname' ||
        key == 'profile_signature' ||
        key == HiveOceanSyncStateStore.cursorKey ||
        key.startsWith('daily_mood_') ||
        key.startsWith('daily_summary_') ||
        key.startsWith('ocean_sync_updated_at_') ||
        key.startsWith('ocean_sync_deleted_record_');
  }
}
