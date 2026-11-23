import Darwin
import Flutter
import Metal
import UIKit
import os

/// All mutable state and URLSession delegate callbacks run on the main queue.
final class QwenReviewBridge: NSObject, URLSessionDownloadDelegate, FlutterStreamHandler, @unchecked Sendable {
  private let store = QwenModelStore(directory: FileManager.default.urls(for: .applicationSupportDirectory,
    in: .userDomainMask)[0].appendingPathComponent("QwenReview", isDirectory: true))
  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.urlCache = nil
    config.httpCookieStorage = nil
    config.timeoutIntervalForRequest = 60
    config.timeoutIntervalForResource = 7200
    return URLSession(configuration: config, delegate: self, delegateQueue: .main)
  }()
  private let worker = DispatchQueue(label: "ma.raqmain.najeez.qwen", qos: .userInitiated)
  private var transfer: URLSessionDownloadTask?
  private var verification: Progress?
  private var generation: Progress?
  private var received: Int64 = 0
  private var lastPercent = -1
  private var downloadError: String?
  private var sink: FlutterEventSink?
  private var library: UnsafeMutableRawPointer?
  private let compatible: Bool = {
    #if targetEnvironment(simulator)
    return false
    #else
    guard #available(iOS 16.4, *), ProcessInfo.processInfo.physicalMemory >= 5 * 1024 * 1024 * 1024,
          let device = MTLCreateSystemDefaultDevice(), device.supportsFamily(.apple7) else { return false }
    return true
    #endif
  }()

  override init() {
    super.init()
    try? store.clearInterruptedDownloads()
    for name in [UIApplication.didReceiveMemoryWarningNotification, UIApplication.didEnterBackgroundNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(interrupt), name: name, object: nil)
    }
  }

  @objc private func interrupt() { generation?.cancel() }
  private func status() -> [String: Any] {
    let bytes = store.installedBytes
    let phase: String
    if verification != nil { phase = "verifying" }
    else if transfer != nil { phase = "downloading" }
    else if !compatible { phase = "unsupported" }
    else if bytes == QwenModelStore.bytes { phase = "ready" }
    else { phase = "missing" }
    return ["phase": phase, "total": QwenModelStore.bytes, "received": received, "installed": bytes,
            "error": downloadError ?? ""]
  }
  private func emit() { sink?(status()) }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    emit()
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }

  private func fail(_ code: String) -> FlutterError { FlutterError(code: code, message: nil, details: nil) }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status": result(status())
    case "download":
      guard compatible else { result(fail("unsupported")); return }
      guard transfer == nil, verification == nil, generation == nil, !store.ready else { result(nil); return }
      do {
        try store.prepare()
        let space = try store.directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
          .volumeAvailableCapacityForImportantUsage
        guard let space, space > QwenModelStore.bytes + 128 * 1024 * 1024 else {
          result(fail("storage")); return
        }
        guard os_proc_available_memory() > 1_650_000_000 else { result(fail("memory")); return }
        received = 0
        lastPercent = -1
        downloadError = nil
        transfer = session.downloadTask(with: QwenModelStore.source)
        transfer?.resume()
        emit()
        result(nil)
      } catch { result(fail("storage")) }
    case "cancelDownload":
      transfer?.cancel()
      transfer = nil
      verification?.cancel()
      verification = nil
      received = 0
      downloadError = nil
      emit()
      result(nil)
    case "remove":
      guard generation == nil, transfer == nil, verification == nil else { result(fail("busy")); return }
      do {
        if FileManager.default.fileExists(atPath: store.directory.path) {
          try FileManager.default.removeItem(at: store.directory)
        }
        received = 0
        downloadError = nil
        emit()
        result(nil)
      } catch { result(fail("storage")) }
    case "cancelGeneration": generation?.cancel(); result(nil)
    case "generate":
      guard compatible, store.ready else { result(fail("unavailable")); return }
      guard generation == nil, transfer == nil, verification == nil else { result(fail("busy")); return }
      guard os_proc_available_memory() > 1_650_000_000 else { result(fail("memory")); return }
      guard ProcessInfo.processInfo.thermalState != .critical else { result(fail("thermal")); return }
      guard let evidence = call.arguments as? String, let directory = Bundle.main.privateFrameworksURL else {
        result(fail("inference")); return
      }
      let flag = Progress(totalUnitCount: 1)
      generation = flag
      worker.async { [self] in
        let response: NSDictionary = autoreleasepool {
          if library == nil {
            let file = directory.appendingPathComponent("NajeezInference.framework/NajeezInference")
            library = dlopen(file.path, RTLD_NOW | RTLD_LOCAL)
          }
          guard let library, let symbol = dlsym(library, "najeez_qwen_review") else { return ["error":"runtime"] }
          typealias Entry = @convention(c) (UnsafeRawPointer) -> UnsafeMutableRawPointer
          let run = unsafeBitCast(symbol, to: Entry.self)
          let request: NSDictionary = ["path":store.installed.path, "data":evidence, "cancel":flag]
          return withExtendedLifetime(request) {
            Unmanaged<NSDictionary>.fromOpaque(run(Unmanaged.passUnretained(request).toOpaque())).takeRetainedValue()
          }
        }
        DispatchQueue.main.async {
          self.generation = nil
          if flag.isCancelled { result(self.fail("cancelled")) }
          else if let text = response["text"] as? String { result(text) }
          else { result(self.fail(response["error"] as? String ?? "inference")) }
        }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(request.url?.scheme == "https" ? request : nil)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    guard downloadTask == transfer else { return }
    if totalBytesWritten > QwenModelStore.bytes {
      downloadTask.cancel()
      transfer = nil
      downloadError = "integrity"
      emit()
      return
    }
    received = totalBytesWritten
    let percent = Int(received * 100 / QwenModelStore.bytes)
    if percent != lastPercent { lastPercent = percent; emit() }
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard downloadTask == transfer else { return }
    transfer = nil
    guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else {
      downloadError = "network"; emit(); return
    }
    let staging = store.directory.appendingPathComponent(UUID().uuidString + ".partial")
    do { try FileManager.default.moveItem(at: location, to: staging) }
    catch { downloadError = "storage"; emit(); return }
    let flag = Progress(totalUnitCount: 1)
    verification = flag
    emit()
    worker.async { [self] in
      let valid = (try? store.verify(staging, cancellation: flag)) != nil
      DispatchQueue.main.async {
        defer { try? FileManager.default.removeItem(at: staging) }
        guard self.verification === flag else { return }
        self.verification = nil
        if valid {
          do { try self.store.publish(staging) } catch { self.downloadError = "storage" }
        } else { self.downloadError = "integrity" }
        self.emit()
      }
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard task == transfer, let error else { return }
    transfer = nil
    downloadError = (error as NSError).code == NSURLErrorCannotWriteToFile ? "storage" : "network"
    emit()
  }
}
