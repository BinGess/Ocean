import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../network/ocean_api_client.dart';

/// 推送通知类型
enum PushNotificationType {
  sarahLetter,
  unknown,
}

/// 推送通知点击事件
class PushNotificationTapEvent {
  const PushNotificationTapEvent({required this.type, this.payload});

  final PushNotificationType type;
  final Map<String, dynamic>? payload;
}

/// 客户端推送通知服务
///
/// 职责：
/// 1. 通过 MethodChannel 与 iOS 原生层通信，获取 APNs 设备 Token
/// 2. 将 Token 注册到服务端（需要已登录，失败静默忽略）
/// 3. 监听通知点击事件，通过 Stream 暴露给 UI 层
class PushNotificationService {
  PushNotificationService({required OceanDeviceApi deviceApi})
      : _deviceApi = deviceApi;

  static const _channelName = 'mindflow/push_notifications';
  static const _channel = MethodChannel(_channelName);

  final OceanDeviceApi _deviceApi;
  final StreamController<PushNotificationTapEvent> _tapController =
      StreamController.broadcast();

  /// 通知点击事件流，UI 层可 listen 以响应跳转
  Stream<PushNotificationTapEvent> get onNotificationTap => _tapController.stream;

  /// 初始化：向原生层注册 MethodCall 处理器并尝试获取当前 Token
  Future<void> init() async {
    _channel.setMethodCallHandler(_handleNativeCall);

    // 应用启动时，尝试获取已有 Token（如 iOS 已批准权限并已注册）
    try {
      final token = await _channel.invokeMethod<String>('getDeviceToken');
      if (token != null && token.isNotEmpty) {
        await _tryRegisterToken(token);
      }
    } catch (e) {
      // 权限未授予或原生层还未准备好，忽略
      debugPrint('PushNotificationService: getDeviceToken failed: $e');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceToken':
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) {
          await _tryRegisterToken(token);
        }
      case 'onNotificationTap':
        _handleTap(call.arguments);
    }
    return null;
  }

  void _handleTap(dynamic arguments) {
    final payload = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : null;
    final typeStr = payload?['type'] as String?;
    final type = switch (typeStr) {
      'sarah_letter' => PushNotificationType.sarahLetter,
      _ => PushNotificationType.unknown,
    };
    _tapController.add(PushNotificationTapEvent(type: type, payload: payload));
  }

  /// 用户登录成功后调用，重试 Token 注册。
  /// 首次启动时 [init] 因用户未登录而注册失败，登录完成后通过此方法补注册。
  Future<void> retryTokenRegistration() async {
    try {
      final token = await _channel.invokeMethod<String>('getDeviceToken');
      if (token != null && token.isNotEmpty) {
        await _tryRegisterToken(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService: retryTokenRegistration failed: $e');
    }
  }

  Future<void> _tryRegisterToken(String token) async {
    try {
      await _deviceApi.registerDeviceToken(token, platform: 'ios');
      debugPrint('PushNotificationService: token registered ✅');
    } catch (e) {
      // 用户未登录或网络错误 — 静默忽略，下次登录后会重试
      debugPrint('PushNotificationService: token registration failed: $e');
    }
  }

  /// 清除 App 角标（在用户跳转到对应页面后调用）
  Future<void> clearBadge() async {
    try {
      await _channel.invokeMethod<void>('clearBadge');
    } catch (_) {
      // 平台不支持时静默忽略
    }
  }

  void dispose() {
    _tapController.close();
  }
}
