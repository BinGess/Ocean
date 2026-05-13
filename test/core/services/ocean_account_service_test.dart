import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/core/services/icloud_sync_service.dart';
import 'package:mindflow/core/services/ocean_account_cache_service.dart';
import 'package:mindflow/core/services/ocean_account_service.dart';
import 'package:mindflow/core/services/ocean_sync_service.dart';

void main() {
  test('login migrates local data, restores server snapshot, and notifies',
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
    expect(syncService.pushAllLocalDataCount, 1);
    expect(syncService.restoreSnapshotCount, 1);
    expect(notifications, 1);
    expect(cacheService.clearCount, 0);
    await subscription.cancel();
  });

  test('login disables iCloud backup before account data migration', () async {
    final api = _FakeAccountApi();
    final syncService = _FakeSyncService();
    final iCloudSyncService = _FakeICloudSyncService(enabled: true);
    syncService.observedICloud = iCloudSyncService;
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: _FakeAccountCacheService(),
      refreshService: OceanAccountDataRefreshService(),
      iCloudSyncService: iCloudSyncService,
    );

    await service.login(email: 'user@example.com', password: 'password123');

    expect(iCloudSyncService.setEnabledCalls, [false]);
    expect(syncService.pushObservedICloudDisabled, isTrue);
  });

  test(
      'login keeps auth state and skips snapshot when local migration upload fails',
      () async {
    final api = _FakeAccountApi();
    final syncService = _FakeSyncService()
      ..pushError = Exception('temporary sync failure');
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

    await expectLater(
      service.login(
        email: 'user@example.com',
        password: 'password123',
      ),
      throwsA(isA<OceanLocalMigrationException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(syncService.pushAllLocalDataCount, 1);
    expect(syncService.restoreSnapshotCount, 0);
    expect(api.logoutCount, 0);
    expect(api.loggedInEmail, 'user@example.com');
    expect(notifications, 0);
    await subscription.cancel();
  });

  test(
      'login does not restore server snapshot when local migration upload fails',
      () async {
    final api = _FakeAccountApi();
    final syncService = _FakeSyncService()
      ..pushError = Exception('temporary sync failure');
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: _FakeAccountCacheService(),
      refreshService: OceanAccountDataRefreshService(),
    );

    await expectLater(
      service.login(
        email: 'user@example.com',
        password: 'password123',
      ),
      throwsA(isA<OceanLocalMigrationException>()),
    );

    expect(syncService.pushAllLocalDataCount, 1);
    expect(syncService.restoreSnapshotCount, 0);
  });

  test('retryLocalMigration reuses existing auth without another login',
      () async {
    final api = _FakeAccountApi()..loggedInPhone = '13800138000';
    final syncService = _FakeSyncService();
    final notifier = OceanAccountDataRefreshService();
    var notifications = 0;
    final subscription = notifier.changes.listen((_) => notifications++);
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: _FakeAccountCacheService(),
      refreshService: notifier,
    );

    await service.retryLocalMigration();
    await Future<void>.delayed(Duration.zero);

    expect(syncService.pushAllLocalDataCount, 1);
    expect(syncService.restoreSnapshotCount, 1);
    expect(api.smsLoginCount, 0);
    expect(notifications, 1);
    await subscription.cancel();
  });

  test('register still succeeds when post-register sync fails', () async {
    final api = _FakeAccountApi();
    final syncService = _FakeSyncService()
      ..restoreError = Exception('temporary restore failure');
    final cacheService = _FakeAccountCacheService();
    final notifier = OceanAccountDataRefreshService();
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: cacheService,
      refreshService: notifier,
    );

    final tokens = await service.register(
      email: 'user@example.com',
      password: 'password123',
      nickname: 'Ocean',
    );

    expect(tokens.accessToken, 'access');
    expect(api.loggedInEmail, 'user@example.com');
    expect(syncService.pushAllLocalDataCount, 1);
    expect(syncService.restoreSnapshotCount, 1);
  });

  test('sms login restores server snapshot and notifies', () async {
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

    await service.sendSmsCode(phone: '13800138000');
    await service.loginWithSms(phone: '13800138000', code: '123456');
    await Future<void>.delayed(Duration.zero);

    expect(api.smsCodeSentTo, '13800138000');
    expect(api.loggedInPhone, '13800138000');
    expect(syncService.pushAllLocalDataCount, 1);
    expect(syncService.restoreSnapshotCount, 1);
    expect(notifications, 1);
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

  test('restoreSignedInSession restores snapshot only when token exists',
      () async {
    final api = _FakeAccountApi()..loggedInEmail = 'user@example.com';
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

    final restored = await service.restoreSignedInSession();
    await Future<void>.delayed(Duration.zero);

    expect(restored, isTrue);
    expect(syncService.pushAllLocalDataCount, 0);
    expect(syncService.restoreSnapshotCount, 1);
    expect(notifications, 1);
    await subscription.cancel();
  });

  test(
      'restoreSignedInSession disables existing iCloud backup for signed-in users',
      () async {
    final api = _FakeAccountApi()..loggedInEmail = 'user@example.com';
    final syncService = _FakeSyncService();
    final iCloudSyncService = _FakeICloudSyncService(enabled: true);
    syncService.observedICloud = iCloudSyncService;
    final service = OceanAccountService(
      api: api,
      syncService: syncService,
      cacheService: _FakeAccountCacheService(),
      refreshService: OceanAccountDataRefreshService(),
      iCloudSyncService: iCloudSyncService,
    );

    final restored = await service.restoreSignedInSession();

    expect(restored, isTrue);
    expect(iCloudSyncService.setEnabledCalls, [false]);
    expect(syncService.restoreObservedICloudDisabled, isTrue);
  });
}

class _FakeAccountApi implements OceanAccountApi {
  String? loggedInEmail;
  String? loggedInPhone;
  String? smsCodeSentTo;
  int logoutCount = 0;
  int smsLoginCount = 0;

  @override
  Future<String?> get currentEmail async => loggedInEmail;

  @override
  Future<bool> get isSignedIn async =>
      loggedInEmail != null || loggedInPhone != null;

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
    loggedInPhone = null;
  }

  @override
  Future<void> sendSmsCode({required String phone}) async {
    smsCodeSentTo = phone;
  }

  @override
  Future<OceanAuthTokens> loginWithSms({
    required String phone,
    required String code,
  }) async {
    smsLoginCount += 1;
    loggedInPhone = phone;
    return const OceanAuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
    );
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
  int pushAllLocalDataCount = 0;
  int restoreSnapshotCount = 0;
  _FakeICloudSyncService? observedICloud;
  bool pushObservedICloudDisabled = false;
  bool restoreObservedICloudDisabled = false;
  Object? pushError;
  Object? restoreError;

  @override
  Future<OceanSyncResult> pushAllLocalData() async {
    pushAllLocalDataCount += 1;
    final iCloud = observedICloud;
    if (iCloud != null) {
      pushObservedICloudDisabled = !await iCloud.isEnabled;
    }
    final error = pushError;
    if (error != null) throw error;
    return const OceanSyncResult(cursor: '1');
  }

  @override
  Future<OceanSyncResult> restoreSnapshot() async {
    restoreSnapshotCount += 1;
    final iCloud = observedICloud;
    if (iCloud != null) {
      restoreObservedICloudDisabled = !await iCloud.isEnabled;
    }
    final error = restoreError;
    if (error != null) throw error;
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

class _FakeICloudSyncService extends Fake implements ICloudSyncService {
  _FakeICloudSyncService({required bool enabled}) : _enabled = enabled;

  bool _enabled;
  final List<bool> setEnabledCalls = [];

  @override
  Future<bool> get isEnabled async => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    setEnabledCalls.add(enabled);
    _enabled = enabled;
  }
}
