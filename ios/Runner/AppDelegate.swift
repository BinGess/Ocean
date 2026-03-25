import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let iCloudChannelName = "mindflow/icloud_sync"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      configureICloudChannel(messenger: controller.binaryMessenger)
    }

    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func configureICloudChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: iCloudChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
        return
      }

      switch call.method {
      case "getICloudContainerPath":
        result(self.resolveICloudContainerPath())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func resolveICloudContainerPath() -> String? {
    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
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
