import 'package:flutter/foundation.dart';

import '../../data/datasources/local/hive_database.dart';
import '../network/ocean_api_client.dart';

class OceanInstallationService {
  OceanInstallationService({
    required HiveDatabase database,
    required OceanTokenStore tokenStore,
  })  : _database = database,
        _tokenStore = tokenStore;

  static const installMarkerKey = 'ocean_installation_marker';

  final HiveDatabase _database;
  final OceanTokenStore _tokenStore;

  Future<void> reconcileInstallState() async {
    final marker = _database.settingsBox.get(installMarkerKey) as String?;
    if (marker == 'true') return;

    if (_looksLikeFreshLocalInstall()) {
      await _tokenStore.clear();
      debugPrint('OceanInstallationService: cleared stale account tokens');
    }

    await _database.settingsBox.put(installMarkerKey, 'true');
  }

  bool _looksLikeFreshLocalInstall() {
    return _database.recordsBox.length == 0 &&
        _database.weeklyInsightsBox.length == 0 &&
        _database.insightReportsBox.length == 0 &&
        _database.settingsBox.length == 0;
  }
}
