import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testICloudResolverUsesExplicitContainerIdentifier() {
    var requestedIdentifier: String?
    let containerURL = URL(fileURLWithPath: "/tmp/mindflow-ios-icloud", isDirectory: true)

    let resolver = ICloudContainerResolver(
      containerIdentifier: "iCloud.com.mindflow.app.mindflow",
      identityTokenProvider: { "signed-in-token" as NSString },
      ubiquityURLProvider: { identifier in
        requestedIdentifier = identifier
        return containerURL
      },
      directoryCreator: { _ in }
    )

    let resolution = resolver.resolve()

    XCTAssertEqual(requestedIdentifier, "iCloud.com.mindflow.app.mindflow")
    XCTAssertEqual(resolution.status, .available)
    XCTAssertEqual(
      resolution.path,
      containerURL.appendingPathComponent("Documents", isDirectory: true).path
    )
  }

  func testICloudResolverReturnsNotSignedInStatusWhenIdentityTokenIsMissing() {
    let resolver = ICloudContainerResolver(
      containerIdentifier: "iCloud.com.mindflow.app.mindflow",
      identityTokenProvider: { nil },
      ubiquityURLProvider: { _ in nil },
      directoryCreator: { _ in }
    )

    let resolution = resolver.resolve()

    XCTAssertEqual(resolution.status, .notSignedIn)
    XCTAssertNil(resolution.path)
  }

  func testICloudResolverReturnsDriveUnavailableStatusWhenContainerCannotBeResolved() {
    let resolver = ICloudContainerResolver(
      containerIdentifier: "iCloud.com.mindflow.app.mindflow",
      identityTokenProvider: { "signed-in-token" as NSString },
      ubiquityURLProvider: { _ in nil },
      directoryCreator: { _ in }
    )

    let resolution = resolver.resolve()

    XCTAssertEqual(resolution.status, .driveUnavailable)
    XCTAssertNil(resolution.path)
  }

}
