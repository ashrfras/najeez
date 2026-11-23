import CryptoKit
import Flutter
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testOnlyVerifiedWeightsCanBecomeReady() throws {
    let files = FileManager.default
    let folder = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? files.removeItem(at: folder) }
    let weights = Data("sample".utf8)
    let digest = SHA256.hash(data: weights).map { String(format: "%02x", $0) }.joined()
    let store = QwenModelStore(directory: folder, expectedSize: Int64(weights.count), digest: digest)
    try store.prepare()
    let partial = folder.appendingPathComponent("download.partial")
    let progress = Progress(totalUnitCount: 1)

    try Data("broken".utf8).write(to: partial)
    XCTAssertThrowsError(try store.verify(partial, cancellation: progress))
    XCTAssertFalse(store.ready)
    try weights.write(to: partial)
    let cancelled = Progress(totalUnitCount: 1)
    cancelled.cancel()
    XCTAssertThrowsError(try store.verify(partial, cancellation: cancelled))
    try store.verify(partial, cancellation: progress)
    try store.publish(partial)

    try Data().write(to: partial)
    try store.clearInterruptedDownloads()
    XCTAssertTrue(store.ready)
    XCTAssertEqual(store.installedBytes, Int64(weights.count))
    XCTAssertFalse(files.fileExists(atPath: partial.path))
  }

  #if targetEnvironment(simulator)
  func testSimulatorDeclinesDownloadBeforeStartingATransfer() {
    let bridge = QwenReviewBridge()
    bridge.handle(FlutterMethodCall(methodName: "status", arguments: nil)) { state in
      XCTAssertEqual((state as? [String: Any])?["phase"] as? String, "unsupported")
    }
    bridge.handle(FlutterMethodCall(methodName: "download", arguments: nil)) { response in
      XCTAssertEqual((response as? FlutterError)?.code, "unsupported")
    }
  }
  #endif
}
