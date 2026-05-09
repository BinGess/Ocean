import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/ocean_api_client.dart';
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

class OceanAccountService {
  OceanAccountService({
    required OceanAccountApi api,
    required OceanAccountSyncService syncService,
    required OceanAccountCacheService cacheService,
    required OceanAccountDataRefreshService refreshService,
  })  : _api = api,
        _syncService = syncService,
        _cacheService = cacheService,
        _refreshService = refreshService;

  final OceanAccountApi _api;
  final OceanAccountSyncService _syncService;
  final OceanAccountCacheService _cacheService;
  final OceanAccountDataRefreshService _refreshService;

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

  Future<void> _trySyncAfterAuth(String action) async {
    try {
      await _syncService.pushAllLocalData();
    } catch (error) {
      debugPrint('OceanAccountService: $action local migration failed: $error');
    }

    try {
      await _syncService.restoreSnapshot();
    } catch (error) {
      debugPrint(
          'OceanAccountService: $action snapshot restore failed: $error');
    }

    _refreshService.notifyChanged();
  }
}
