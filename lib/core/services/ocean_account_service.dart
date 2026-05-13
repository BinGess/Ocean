import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/ocean_api_client.dart';
import 'icloud_sync_service.dart';
import 'ocean_account_cache_service.dart';
import 'ocean_sync_service.dart';

class OceanAccountDataRefreshService {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
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
  })  : _api = api,
        _syncService = syncService,
        _cacheService = cacheService,
        _refreshService = refreshService,
        _iCloudSyncService = iCloudSyncService;

  final OceanAccountApi _api;
  final OceanAccountSyncService _syncService;
  final OceanAccountCacheService _cacheService;
  final OceanAccountDataRefreshService _refreshService;
  final ICloudSyncService? _iCloudSyncService;

  Future<bool> get isSignedIn => _api.isSignedIn;

  Future<String?> get currentEmail => _api.currentEmail;

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
    await _disableICloudBackupForAccountSync('restore signed-in session');
    try {
      await _syncService.restoreSnapshot();
    } catch (error) {
      debugPrint(
          'OceanAccountService: restore signed-in session failed: $error');
    }
    _refreshService.notifyChanged();
    return true;
  }

  Future<void> logout() async {
    await _api.logout();
    await _cacheService.clearAccountCache();
    _refreshService.notifyChanged();
  }

  Future<void> retryLocalMigration() async {
    if (!await _api.isSignedIn) {
      throw const OceanAuthException('Missing access token');
    }
    await _completeLocalMigration('retry local migration');
  }

  Future<void> _trySyncAfterAuth(String action) async {
    await _disableICloudBackupForAccountSync(action);
    await _completeLocalMigration(action);
  }

  Future<void> _completeLocalMigration(String action) async {
    var localMigrationSucceeded = true;
    Object? localMigrationError;
    try {
      await _syncService.pushAllLocalData();
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

    try {
      await _syncService.restoreSnapshot();
    } catch (error) {
      debugPrint(
          'OceanAccountService: $action snapshot restore failed: $error');
    }

    _refreshService.notifyChanged();
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
