import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
    }
  }
}

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
    guard let containerURL = FileManager.default.url(
      forUbiquityContainerIdentifier: containerIdentifier
    ) else {
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
