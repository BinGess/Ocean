/// 应用锁服务
/// 管理密码验证、生物识别、自动锁定等功能
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// 自动锁定时间选项
enum AutoLockDuration {
  immediately(0, '立即'),
  oneMinute(60, '1分钟后'),
  fiveMinutes(300, '5分钟后'),
  fifteenMinutes(900, '15分钟后');

  final int seconds;
  final String label;

  const AutoLockDuration(this.seconds, this.label);

  static AutoLockDuration fromSeconds(int seconds) {
    return AutoLockDuration.values.firstWhere(
      (d) => d.seconds == seconds,
      orElse: () => AutoLockDuration.immediately,
    );
  }
}

/// 生物识别类型（应用内部使用）
enum AppBiometricType {
  none,
  fingerprint,
  face,
  iris,
}

/// 应用锁服务
class AppLockService {
  static const String _keyPasscode = 'app_lock_passcode';
  static const String _keyEnabled = 'app_lock_enabled';
  static const String _keyBiometricEnabled = 'app_lock_biometric_enabled';
  static const String _keyAutoLockDuration = 'app_lock_auto_lock_duration';
  static const String _keyFailedAttempts = 'app_lock_failed_attempts';
  static const String _keyLockoutEndTime = 'app_lock_lockout_end_time';
  static const String _keyFirstLaunch = 'app_first_launch_marker';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  // 内存缓存
  bool? _isEnabled;
  bool? _isBiometricEnabled;
  AutoLockDuration? _autoLockDuration;
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  // 后台时间记录
  DateTime? _lastBackgroundTime;

  // 状态通知
  final _lockStateController = StreamController<bool>.broadcast();
  Stream<bool> get lockStateStream => _lockStateController.stream;

  AppLockService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  /// 初始化服务
  Future<void> init() async {
    // 检查是否首次安装，清除可能残留的旧密码
    await _checkFirstLaunch();
    // 加载缓存
    await _loadCachedSettings();
  }

  /// 检查首次安装
  Future<void> _checkFirstLaunch() async {
    try {
      final marker = await _secureStorage.read(key: _keyFirstLaunch);
      if (marker == null) {
        // 首次安装，清除可能的残留数据
        await _secureStorage.delete(key: _keyPasscode);
        await _secureStorage.delete(key: _keyEnabled);
        await _secureStorage.delete(key: _keyBiometricEnabled);
        await _secureStorage.delete(key: _keyAutoLockDuration);
        await _secureStorage.delete(key: _keyFailedAttempts);
        await _secureStorage.delete(key: _keyLockoutEndTime);
        // 设置标记
        await _secureStorage.write(key: _keyFirstLaunch, value: 'true');
      }
    } catch (e) {
      debugPrint('AppLockService: 检查首次安装失败: $e');
    }
  }

  /// 加载缓存设置
  Future<void> _loadCachedSettings() async {
    try {
      final enabled = await _secureStorage.read(key: _keyEnabled);
      _isEnabled = enabled == 'true';

      final biometricEnabled =
          await _secureStorage.read(key: _keyBiometricEnabled);
      _isBiometricEnabled = biometricEnabled == 'true';

      final autoLockStr = await _secureStorage.read(key: _keyAutoLockDuration);
      if (autoLockStr != null) {
        _autoLockDuration = AutoLockDuration.fromSeconds(int.parse(autoLockStr));
      } else {
        _autoLockDuration = AutoLockDuration.immediately;
      }

      final failedStr = await _secureStorage.read(key: _keyFailedAttempts);
      _failedAttempts = failedStr != null ? int.parse(failedStr) : 0;

      final lockoutStr = await _secureStorage.read(key: _keyLockoutEndTime);
      if (lockoutStr != null) {
        _lockoutEndTime = DateTime.parse(lockoutStr);
      }
    } catch (e) {
      debugPrint('AppLockService: 加载设置失败: $e');
    }
  }

  /// 是否启用了应用锁
  Future<bool> get isEnabled async {
    if (_isEnabled != null) return _isEnabled!;
    final enabled = await _secureStorage.read(key: _keyEnabled);
    _isEnabled = enabled == 'true';
    return _isEnabled!;
  }

  /// 是否启用了生物识别
  Future<bool> get isBiometricEnabled async {
    if (_isBiometricEnabled != null) return _isBiometricEnabled!;
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    _isBiometricEnabled = enabled == 'true';
    return _isBiometricEnabled!;
  }

  /// 获取自动锁定时间
  Future<AutoLockDuration> get autoLockDuration async {
    if (_autoLockDuration != null) return _autoLockDuration!;
    final str = await _secureStorage.read(key: _keyAutoLockDuration);
    if (str != null) {
      _autoLockDuration = AutoLockDuration.fromSeconds(int.parse(str));
    } else {
      _autoLockDuration = AutoLockDuration.immediately;
    }
    return _autoLockDuration!;
  }

  /// 是否已设置密码
  Future<bool> get hasPasscode async {
    final passcode = await _secureStorage.read(key: _keyPasscode);
    return passcode != null && passcode.isNotEmpty;
  }

  /// 检查设备是否支持生物识别
  Future<bool> get canUseBiometrics async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('AppLockService: 检查生物识别支持失败: $e');
      return false;
    }
  }

  /// 获取可用的生物识别类型
  Future<List<AppBiometricType>> get availableBiometrics async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available.map((type) {
        if (type == BiometricType.fingerprint) {
          return AppBiometricType.fingerprint;
        } else if (type == BiometricType.face) {
          return AppBiometricType.face;
        } else if (type == BiometricType.iris) {
          return AppBiometricType.iris;
        } else {
          return AppBiometricType.none;
        }
      }).where((t) => t != AppBiometricType.none).toList();
    } catch (e) {
      debugPrint('AppLockService: 获取生物识别类型失败: $e');
      return [];
    }
  }

  /// 获取生物识别名称（FaceID/TouchID）
  Future<String> get biometricName async {
    final types = await availableBiometrics;
    if (types.contains(AppBiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(AppBiometricType.fingerprint)) {
      return 'Touch ID';
    } else if (types.contains(AppBiometricType.iris)) {
      return '虹膜识别';
    }
    return '生物识别';
  }

  /// 是否处于锁定状态（密码错误次数过多）
  Future<bool> get isLockedOut async {
    if (_lockoutEndTime == null) return false;
    if (DateTime.now().isAfter(_lockoutEndTime!)) {
      // 锁定已过期，重置
      await _resetFailedAttempts();
      return false;
    }
    return true;
  }

  /// 获取锁定剩余时间（秒）
  Future<int> get lockoutRemainingSeconds async {
    if (_lockoutEndTime == null) return 0;
    final remaining = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// 设置密码
  Future<bool> setPasscode(String passcode) async {
    if (passcode.length != 4 && passcode.length != 6) {
      return false;
    }
    try {
      await _secureStorage.write(key: _keyPasscode, value: passcode);
      await _secureStorage.write(key: _keyEnabled, value: 'true');
      _isEnabled = true;
      await _resetFailedAttempts();
      _lockStateController.add(true);
      return true;
    } catch (e) {
      debugPrint('AppLockService: 设置密码失败: $e');
      return false;
    }
  }

  /// 验证密码
  Future<bool> verifyPasscode(String passcode) async {
    // 检查是否锁定
    if (await isLockedOut) {
      return false;
    }

    try {
      final storedPasscode = await _secureStorage.read(key: _keyPasscode);
      if (storedPasscode == passcode) {
        await _resetFailedAttempts();
        return true;
      } else {
        await _incrementFailedAttempts();
        return false;
      }
    } catch (e) {
      debugPrint('AppLockService: 验证密码失败: $e');
      return false;
    }
  }

  /// 更改密码
  Future<bool> changePasscode(String oldPasscode, String newPasscode) async {
    if (!await verifyPasscode(oldPasscode)) {
      return false;
    }
    return await setPasscode(newPasscode);
  }

  /// 使用生物识别验证
  Future<bool> authenticateWithBiometrics() async {
    if (!await isBiometricEnabled) {
      return false;
    }

    try {
      final biometricName = await this.biometricName;
      final authenticated = await _localAuth.authenticate(
        localizedReason: '请使用 $biometricName 解锁瞬记',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        await _resetFailedAttempts();
      }
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('AppLockService: 生物识别失败: ${e.code} - ${e.message}');
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled) {
        // 生物识别不可用，禁用它
        await setBiometricEnabled(false);
      }
      return false;
    }
  }

  /// 设置是否启用生物识别
  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _keyBiometricEnabled,
      value: enabled.toString(),
    );
    _isBiometricEnabled = enabled;
  }

  /// 设置自动锁定时间
  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    await _secureStorage.write(
      key: _keyAutoLockDuration,
      value: duration.seconds.toString(),
    );
    _autoLockDuration = duration;
  }

  /// 禁用应用锁
  Future<bool> disable(String passcode) async {
    if (!await verifyPasscode(passcode)) {
      return false;
    }
    try {
      await _secureStorage.delete(key: _keyPasscode);
      await _secureStorage.write(key: _keyEnabled, value: 'false');
      await _secureStorage.write(key: _keyBiometricEnabled, value: 'false');
      _isEnabled = false;
      _isBiometricEnabled = false;
      await _resetFailedAttempts();
      _lockStateController.add(false);
      return true;
    } catch (e) {
      debugPrint('AppLockService: 禁用应用锁失败: $e');
      return false;
    }
  }

  /// 记录进入后台时间
  void onAppBackground() {
    _lastBackgroundTime = DateTime.now();
  }

  /// 检查是否需要显示锁屏
  Future<bool> shouldShowLockScreen() async {
    if (!await isEnabled) {
      return false;
    }

    // 如果没有后台时间记录，说明是冷启动
    if (_lastBackgroundTime == null) {
      return true;
    }

    final duration = await autoLockDuration;
    if (duration == AutoLockDuration.immediately) {
      return true;
    }

    final elapsed = DateTime.now().difference(_lastBackgroundTime!).inSeconds;
    return elapsed >= duration.seconds;
  }

  /// 清除后台时间（解锁成功后调用）
  void clearBackgroundTime() {
    _lastBackgroundTime = DateTime.now();
  }

  /// 增加失败次数
  Future<void> _incrementFailedAttempts() async {
    _failedAttempts++;
    await _secureStorage.write(
      key: _keyFailedAttempts,
      value: _failedAttempts.toString(),
    );

    // 5次失败后锁定1分钟
    if (_failedAttempts >= 5) {
      _lockoutEndTime = DateTime.now().add(const Duration(minutes: 1));
      await _secureStorage.write(
        key: _keyLockoutEndTime,
        value: _lockoutEndTime!.toIso8601String(),
      );
    }
  }

  /// 重置失败次数
  Future<void> _resetFailedAttempts() async {
    _failedAttempts = 0;
    _lockoutEndTime = null;
    await _secureStorage.delete(key: _keyFailedAttempts);
    await _secureStorage.delete(key: _keyLockoutEndTime);
  }

  /// 获取当前失败次数
  int get failedAttempts => _failedAttempts;

  /// 释放资源
  void dispose() {
    _lockStateController.close();
  }
}
