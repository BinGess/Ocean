/// AI服务授权管理
/// 管理第三方AI服务的用户授权状态
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AI授权服务
class AIAuthService {
  static const String _keyAIAuthStatus = 'ai_auth_status';
  static const String _keyAIAuthTimestamp = 'ai_auth_timestamp';

  final FlutterSecureStorage _secureStorage;

  // 内存缓存
  bool? _isAuthorized;
  DateTime? _authorizedTime;

  // 状态通知流
  final _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateStream => _authStateController.stream;

  AIAuthService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// 初始化服务
  Future<void> init() async {
    await _loadCachedSettings();
  }

  /// 加载缓存设置
  Future<void> _loadCachedSettings() async {
    try {
      final status = await _secureStorage.read(key: _keyAIAuthStatus);
      _isAuthorized = status == 'true';

      final timestampStr = await _secureStorage.read(key: _keyAIAuthTimestamp);
      if (timestampStr != null) {
        _authorizedTime = DateTime.parse(timestampStr);
      }
    } catch (e) {
      debugPrint('AIAuthService: 加载设置失败: $e');
    }
  }

  /// 检查是否已授权
  Future<bool> get isAuthorized async {
    try {
      if (_isAuthorized != null) return _isAuthorized!;
      final status = await _secureStorage.read(key: _keyAIAuthStatus);
      _isAuthorized = status == 'true';
      return _isAuthorized!;
    } catch (e) {
      debugPrint('AIAuthService: 读取授权状态失败: $e');
      // 默认为未授权（安全第一）
      return false;
    }
  }

  /// 授予授权
  Future<void> grant() async {
    try {
      await _secureStorage.write(key: _keyAIAuthStatus, value: 'true');
      final now = DateTime.now();
      await _secureStorage.write(
        key: _keyAIAuthTimestamp,
        value: now.toIso8601String(),
      );

      _isAuthorized = true;
      _authorizedTime = now;
      _authStateController.add(true);

      debugPrint('AIAuthService: 授权已授予');
    } catch (e) {
      debugPrint('AIAuthService: 授予授权失败: $e');
    }
  }

  /// 撤销授权
  Future<void> revoke() async {
    try {
      await _secureStorage.write(key: _keyAIAuthStatus, value: 'false');

      _isAuthorized = false;
      _authStateController.add(false);

      debugPrint('AIAuthService: 授权已撤销');
    } catch (e) {
      debugPrint('AIAuthService: 撤销授权失败: $e');
    }
  }

  /// 获取授权时间
  Future<DateTime?> get authorizedTime async {
    try {
      if (_authorizedTime != null) return _authorizedTime;
      final timestampStr = await _secureStorage.read(key: _keyAIAuthTimestamp);
      if (timestampStr != null) {
        _authorizedTime = DateTime.parse(timestampStr);
        return _authorizedTime;
      }
      return null;
    } catch (e) {
      debugPrint('AIAuthService: 读取授权时间失败: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _authStateController.close();
  }
}
