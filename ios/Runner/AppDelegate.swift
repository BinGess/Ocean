import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate,
  FlutterImplicitEngineDelegate
{
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // ── 推送通知权限 ────────────────────────────────────────────────────────
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, _ in
      guard granted else { return }
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }

    // 冷启动（App 未运行时点击通知）
    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      PushNotificationChannel.sendNotificationTap(notification)
    }

    return true
  }

  // APNs 成功注册后回调：将 Token 发送给 Flutter
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    PushNotificationChannel.sendToken(tokenString)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("APNs registration failed: \(error)")
  }

  // UNUserNotificationCenterDelegate：前台收到通知时显示横幅
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
      -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }

  // UNUserNotificationCenterDelegate：用户点击通知（前台/后台均会回调）
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if let payload = userInfo as? [String: Any] {
      PushNotificationChannel.sendNotificationTap(payload)
    }
    completionHandler()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

@objc class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      ICloudSyncChannel.configure(messenger: controller.binaryMessenger)
      PushNotificationChannel.configure(messenger: controller.binaryMessenger)
    }
  }
}

// MARK: - ICloud Sync Channel

private enum ICloudSyncChannel {
  private static let channelName = "mindflow/icloud_sync"
  private static let containerIdentifier = "iCloud.com.mindflow.app.mindflow"

  static func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getICloudContainerPath":
        result(resolveICloudContainerPath())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func resolveICloudContainerPath() -> String? {
    guard
      let containerURL = FileManager.default.url(
        forUbiquityContainerIdentifier: containerIdentifier
      )
    else {
      return nil
    }

    let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: documentsURL,
        withIntermediateDirectories: true
      )
      return documentsURL.path
    } catch {
      return nil
    }
  }
}

// MARK: - Push Notification Channel

/// 原生 ↔ Flutter 推送通知桥
///
/// - Flutter → 原生：`getDeviceToken` → 返回当前已持有的 APNs Token（可为 nil）
/// - 原生 → Flutter：`onDeviceToken(token)`   — APNs Token 更新
///                    `onNotificationTap(payload)` — 用户点击通知
enum PushNotificationChannel {
  private static let channelName = "mindflow/push_notifications"

  /// 最近一次收到的 APNs Token（十六进制字符串）
  private static var latestToken: String?
  /// Flutter 引擎就绪前收到的点击事件，在配置时补发
  private static var pendingTapPayload: [String: Any]?
  private static var channel: FlutterMethodChannel?

  static func configure(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel = ch

    ch.setMethodCallHandler { call, result in
      switch call.method {
      case "getDeviceToken":
        result(latestToken)
      case "clearBadge":
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = 0
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 引擎就绪后，补发冷启动点击事件
    if let payload = pendingTapPayload {
      ch.invokeMethod("onNotificationTap", arguments: payload)
      pendingTapPayload = nil
    }
  }

  /// APNs 注册成功后调用，将 Token 同步给 Flutter
  static func sendToken(_ token: String) {
    latestToken = token
    channel?.invokeMethod("onDeviceToken", arguments: token)
  }

  /// 用户点击通知后调用，将 payload 同步给 Flutter
  static func sendNotificationTap(_ payload: [String: Any]) {
    guard let ch = channel else {
      // Flutter 引擎尚未就绪（冷启动场景），暂存并在 configure 时补发
      pendingTapPayload = payload
      return
    }
    ch.invokeMethod("onNotificationTap", arguments: payload)
  }
}
