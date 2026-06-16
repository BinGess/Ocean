import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/ocean_api_client.dart';
import 'icloud_sync_service.dart';
import 'ocean_account_cache_service.dart';
import 'ocean_record_ownership_service.dart';
import 'ocean_sync_service.dart';
import 'pending_sync_tracker.dart';

class OceanAccountDataRefreshService {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// 通用数据变化（登录、退出、账号切换等）
  Stream<void> get changes => _controller.stream;

  /// Token 过期导致的 session 失效事件（独立于 changes，便于 UI 定向响应）
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  /// Token 刷新失败，session 已强制失效。同时触发 changes，让各页面也感知到。
  void notifySessionExpired() {
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
    notifyChanged();
  }

  void dispose() {
    _controller.close();
    _sessionExpiredController.close();
  }
}

class OceanLocalMigrationException implements Exception {
  const OceanLocalMigrationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class OceanAccountService {
  OceanAccountService({
    required OceanAccountApi api,
    required OceanAccountSyncService syncService,
    required OceanAccountCacheService cacheService,
    required OceanAccountDataRefreshService refreshService,
    ICloudSyncService? iCloudSyncService,
    OceanRecordOwnershipService? ownershipService,
    PendingSyncTracker? pendingSync,
    Future<void> Function()? clearLocalData,
  })  : _api = api,
        _syncService = syncService,
        _cacheService = cacheService,
        _refreshService = refreshService,
        _iCloudSyncService = iCloudSyncService,
        _ownershipService = ownershipService,
        _pendingSync = pendingSync,
        _clearLocalData = clearLocalData ?? (() async {});

  final OceanAccountApi _api;
  final OceanAccountSyncService _syncService;
  final OceanAccountCacheService _cacheService;
  final OceanAccountDataRefreshService _refreshService;
  final ICloudSyncService? _iCloudSyncService;
  final OceanRecordOwnershipService? _ownershipService;
  final PendingSyncTracker? _pendingSync;
  final Future<void> Function() _clearLocalData;

  bool _isFlushingPending = false;

  Future<bool> get isSignedIn => _api.isSignedIn;

  Future<String?> get currentUserId => _api.currentUserId;

  Future<String?> get currentEmail => _api.currentEmail;

  Future<String?> get currentPhone => _api.currentPhone;

  Future<String?> get currentAccountKey => _api.currentAccountKey;

  Future<OceanAuthTokens> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.login(email: email, password: password);
    await _trySyncAfterAuth('login');
    return tokens;
  }

  Future<void> sendSmsCode({required String phone}) {
    return _api.sendSmsCode(phone: phone);
  }

  Future<OceanAuthTokens> loginWithSms({
    required String phone,
    required String code,
  }) async {
    final tokens = await _api.loginWithSms(phone: phone, code: code);
    await _trySyncAfterAuth('sms login');
    return tokens;
  }

  Future<OceanAuthTokens> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final tokens = await _api.register(
      email: email,
      password: password,
      nickname: nickname,
    );
    await _trySyncAfterAuth('register');
    return tokens;
  }

  Future<bool> restoreSignedInSession() async {
    if (!await _api.isSignedIn) return false;
    await _syncActiveAccount();
    await _disableICloudBackupForAccountSync('restore signed-in session');
    try {
      await _syncService.restoreSnapshot();
    } catch (error) {
      debugPrint(
          'OceanAccountService: restore signed-in session failed: $error');
    }
    _refreshService.notifyChanged();
    // 补推之前因写服务端失败而滞留在本地的记录（后台执行，不阻塞启动）。
    unawaited(flushPendingLocalData());
    return true;
  }

  /// 补推「待同步」的本地记录。
  ///
  /// 触发时机：启动恢复会话、回到前台。仅在已登录、且确有待同步数据
  /// （或首次升级回填）时才推送，避免无谓的全量重推。
  /// server-first 写入失败会留下 pending 标记，这里统一补推并清标。
  Future<void> flushPendingLocalData() async {
    final tracker = _pendingSync;
    if (tracker == null || _isFlushingPending) return;
    if (!await _api.isSignedIn) return;

    final backfill = tracker.shouldRunBackfill;
    if (!backfill && !tracker.hasPending) return;

    _isFlushingPending = true;
    try {
      await _syncService.pushAllLocalData();
      await tracker.clear();
      await tracker.markBackfillDone();
      _refreshService.notifyChanged();
    } catch (error) {
      debugPrint(
          'OceanAccountService: flush pending local data failed: $error');
    } finally {
      _isFlushingPending = false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _ownershipService?.detachActiveAccountDataToLocal();
    await _ownershipService?.clearActiveAccount();
    await _cacheService.hideAccountCache();
    _refreshService.notifyChanged();
  }

  /// Permanently deletes the account on the server, wipes all local data,
  /// and clears auth tokens. Throws on server error (so the caller can
  /// show an error message before proceeding).
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await _clearLocalData();
    await _ownershipService?.clearActiveAccount();
    await _cacheService.hideAccountCache();
    _refreshService.notifyChanged();
  }

  Future<void> retryLocalMigration() async {
    if (!await _api.isSignedIn) {
      throw const OceanAuthException('Missing access token');
    }
    await _completeLocalMigration('retry local migration');
  }

  Future<void> _trySyncAfterAuth(String action) async {
    await _syncActiveAccount();
    await _disableICloudBackupForAccountSync(action);
    await _completeLocalMigration(action);
  }

  Future<void> _syncActiveAccount() async {
    final accountKey = await _api.currentAccountKey;
    if (accountKey == null || accountKey.isEmpty) return;
    await _ownershipService?.setActiveAccount(accountKey);
  }

  Future<void> _completeLocalMigration(String action) async {
    var localMigrationSucceeded = true;
    Object? localMigrationError;
    try {
      // 整体限时 60 秒：防止 _pushLocalDataInSmallBatches 按记录逐条上传
      // 时每条都等待超时，导致界面长时间卡在"正在登录并恢复数据..."。
      await _syncService.pushAllLocalData().timeout(
            const Duration(seconds: 60),
          );
    } catch (error) {
      localMigrationSucceeded = false;
      localMigrationError = error;
      debugPrint('OceanAccountService: $action local migration failed: $error');
    }

    if (!localMigrationSucceeded) {
      throw OceanLocalMigrationException(
        '本机数据上传失败。验证码已经通过，请不要重新获取验证码，稍后直接点登录重试上传。',
        localMigrationError,
      );
    }

    // 本地数据已安全上传，pending 标记可清空（登录即全量推送）。
    await _pendingSync?.clear();
    await _pendingSync?.markBackfillDone();

    // 本地数据已安全上传，立即通知各页面刷新并放行登录流程，
    // 让用户直接进入主界面，无需继续等待快照下载。
    _refreshService.notifyChanged();

    // 在后台拉取服务端全量快照（合并其他设备的变更）。
    // 完成后再次 notifyChanged()，各页面会自动更新至最新状态。
    // 此处故意不 await，避免阻塞登录页面的跳转。
    unawaited(
      _syncService
          .restoreSnapshot()
          .timeout(const Duration(seconds: 30))
          .then((_) => _refreshService.notifyChanged())
          .catchError((Object error) {
        debugPrint(
            'OceanAccountService: $action snapshot restore in background failed: $error');
      }),
    );
  }

  Future<void> _disableICloudBackupForAccountSync(String action) async {
    final service = _iCloudSyncService;
    if (service == null || !await service.isEnabled) return;
    try {
      await service.setEnabled(false);
    } catch (error) {
      debugPrint(
          'OceanAccountService: $action failed to disable iCloud backup: $error');
    }
  }
}
