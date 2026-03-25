import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let iCloudChannelName = "mindflow/icloud_sync"

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      configureICloudChannel(messenger: controller.engine.binaryMessenger)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
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
