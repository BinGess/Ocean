import Flutter
import UIKit

enum ICloudContainerStatus: String {
  case available
  case notSignedIn
  case driveUnavailable
  case directoryCreationFailed
}

struct ICloudContainerResolution {
  let status: ICloudContainerStatus
  let path: String?

  var asMap: [String: Any] {
    var result: [String: Any] = ["status": status.rawValue]
    if let path {
      result["path"] = path
    }
    return result
  }
}

final class ICloudContainerResolver {
  private let containerIdentifier: String
  private let identityTokenProvider: () -> Any?
  private let ubiquityURLProvider: (String?) -> URL?
  private let directoryCreator: (URL) throws -> Void

  init(
    containerIdentifier: String = "iCloud.com.mindflow.app.mindflow",
    identityTokenProvider: @escaping () -> Any? = {
      FileManager.default.ubiquityIdentityToken
    },
    ubiquityURLProvider: @escaping (String?) -> URL? = {
      FileManager.default.url(forUbiquityContainerIdentifier: $0)
    },
    directoryCreator: @escaping (URL) throws -> Void = { url in
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  ) {
    self.containerIdentifier = containerIdentifier
    self.identityTokenProvider = identityTokenProvider
    self.ubiquityURLProvider = ubiquityURLProvider
    self.directoryCreator = directoryCreator
  }

  func resolve() -> ICloudContainerResolution {
    guard identityTokenProvider() != nil else {
      return ICloudContainerResolution(status: .notSignedIn, path: nil)
    }

    guard let containerURL = ubiquityURLProvider(containerIdentifier) else {
      return ICloudContainerResolution(status: .driveUnavailable, path: nil)
    }

    let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
    do {
      try directoryCreator(documentsURL)
      return ICloudContainerResolution(status: .available, path: documentsURL.path)
    } catch {
      return ICloudContainerResolution(status: .directoryCreationFailed, path: nil)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let iCloudChannelName = "mindflow/icloud_sync"
  private let iCloudResolver = ICloudContainerResolver()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureICloudChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func configureICloudChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: iCloudChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
        return
      }

      switch call.method {
      case "getICloudContainerInfo":
        result(self.resolveICloudContainerInfo())
      case "getICloudContainerPath":
        result(self.resolveICloudContainerPath())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func resolveICloudContainerInfo() -> [String: Any] {
    return iCloudResolver.resolve().asMap
  }

  private func resolveICloudContainerPath() -> String? {
    return iCloudResolver.resolve().path
  }
}
