import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/core/services/ocean_account_cache_service.dart';
import 'package:mindflow/core/services/ocean_account_service.dart';
import 'package:mindflow/core/services/ocean_sync_service.dart';

void main() {
  test('login restores server snapshot and notifies account data listeners',
      () async {
    final api = _FakeAccountApi();
    final syncService = _FakeSyncService();
    final cacheService = _FakeAccountCacheService();
    final notifier = OceanAccountDataRefreshService();
    var notifications = 0;
    final subscription = notifier.changes.listen((_) => notifications++);
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: cacheService,
      refreshService: notifier,
    );

    await service.login(email: 'user@example.com', password: 'password123');
    await Future<void>.delayed(Duration.zero);

    expect(api.loggedInEmail, 'user@example.com');
    expect(syncService.restoreSnapshotCount, 1);
    expect(notifications, 1);
    expect(cacheService.clearCount, 0);
    await subscription.cancel();
  });

  test('logout clears account cache and notifies account data listeners',
      () async {
    final api = _FakeAccountApi();
    final syncService = _FakeSyncService();
    final cacheService = _FakeAccountCacheService();
    final notifier = OceanAccountDataRefreshService();
    var notifications = 0;
    final subscription = notifier.changes.listen((_) => notifications++);
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: cacheService,
      refreshService: notifier,
    );

    await service.logout();
    await Future<void>.delayed(Duration.zero);

    expect(api.logoutCount, 1);
    expect(cacheService.clearCount, 1);
    expect(syncService.restoreSnapshotCount, 0);
    expect(notifications, 1);
    await subscription.cancel();
  });
}

class _FakeAccountApi implements OceanAccountApi {
  String? loggedInEmail;
  int logoutCount = 0;

  @override
  Future<String?> get currentEmail async => loggedInEmail;

  @override
  Future<bool> get isSignedIn async => loggedInEmail != null;

  @override
  Future<OceanAuthTokens> login({
    required String email,
    required String password,
  }) async {
    loggedInEmail = email;
    return OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      email: email,
    );
  }

  @override
  Future<void> logout() async {
    logoutCount += 1;
    loggedInEmail = null;
  }

  @override
  Future<OceanAuthTokens> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    loggedInEmail = email;
    return OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      email: email,
    );
  }
}

class _FakeSyncService implements OceanAccountSyncService {
  int restoreSnapshotCount = 0;

  @override
  Future<OceanSyncResult> restoreSnapshot() async {
    restoreSnapshotCount += 1;
    return const OceanSyncResult(cursor: '1');
  }
}

class _FakeAccountCacheService implements OceanAccountCacheService {
  int clearCount = 0;

  @override
  Future<void> clearAccountCache() async {
    clearCount += 1;
  }
}
