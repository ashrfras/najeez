import CryptoKit
import Foundation

struct QwenModelStore {
  static let bytes: Int64 = 1_282_439_584
  static let digest = "72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb"
  static let source = URL(string: "https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-GGUF/resolve/dcb19155b962dbb6389f4691a982043a8e651022/Qwen_Qwen3-1.7B-Q4_K_M.gguf")!

  let directory: URL
  let expectedSize: Int64
  let digest: String
  init(directory: URL, expectedSize: Int64 = Self.bytes, digest: String = Self.digest) {
    self.directory = directory
    self.expectedSize = expectedSize
    self.digest = digest
  }

  var installed: URL { directory.appendingPathComponent(digest + ".gguf") }
  var installedBytes: Int64 {
    let size = try? installed.resourceValues(forKeys: [.fileSizeKey]).fileSize
    return Int64(size ?? 0)
  }
  var ready: Bool { installedBytes == expectedSize }

  func prepare() throws {
    var folder = directory
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try folder.setResourceValues(values)
  }

  func clearInterruptedDownloads() throws {
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
      where url.pathExtension == "partial" {
      try FileManager.default.removeItem(at: url)
    }
  }

  // Only a verified file is renamed into the digest-specific installed path.
  // Interrupted downloads and interrupted verification can never become ready.
  func verify(_ file: URL, cancellation: Progress) throws {
    guard Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) == expectedSize else {
      throw CocoaError(.fileReadCorruptFile)
    }
    let handle = try FileHandle(forReadingFrom: file)
    defer { try? handle.close() }
    var hash = SHA256()
    while true {
      if cancellation.isCancelled { throw CancellationError() }
      let finished = try autoreleasepool {
        let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
        if data.isEmpty { return true }
        hash.update(data: data)
        return false
      }
      if finished { break }
    }
    guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == digest else {
      throw CocoaError(.fileReadCorruptFile)
    }
  }

  func publish(_ file: URL) throws {
    if FileManager.default.fileExists(atPath: installed.path) {
      _ = try FileManager.default.replaceItemAt(installed, withItemAt: file)
    } else {
      try FileManager.default.moveItem(at: file, to: installed)
    }
  }
}
