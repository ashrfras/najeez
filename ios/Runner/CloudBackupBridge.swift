import CloudKit
import Flutter
import Foundation

/// One private record and one asset per Apple account. No local files are replaced here.
final class CloudBackupBridge {
  private let container = CKContainer(identifier: "iCloud.ma.raqmain.najeez")
  private let recordID = CKRecord.ID(recordName: "user-backup")
  private var busy = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !busy else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    busy = true
    Task {
      do {
        guard try await container.accountStatus() == .available else {
          throw BackupError.unavailable
        }
        let value: Any?
        switch call.method {
        case "checkAvailable":
          value = nil
        case "latestDate":
          // Exclude the asset so launch discovery does not download the backup.
          let records = try await container.privateCloudDatabase.records(
            for: [recordID], desiredKeys: ["savedAt"])
          let record: CKRecord?
          if let fetched = records[recordID] {
            do { record = try fetched.get() }
            catch let error as CKError where error.code == .unknownItem { record = nil }
          } else {
            record = nil
          }
          value = record == nil ? nil : try timestamp(record!)
        case "save":
          guard let bytes = call.arguments as? FlutterStandardTypedData else {
            throw BackupError.invalidData
          }
          let database = container.privateCloudDatabase
          let record = try await fetchRecord() ?? CKRecord(recordType: "UserBackup", recordID: recordID)
          let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
          defer { try? FileManager.default.removeItem(at: file) }
          try bytes.data.write(to: file, options: .atomic)
          record["payload"] = CKAsset(fileURL: file)
          record["savedAt"] = Date() as CKRecordValue
          // Default conflict policy preserves the existing copy if another device changed it.
          let saved = try await database.save(record)
          value = try timestamp(saved)
        case "read":
          if let record = try await fetchRecord() {
            guard let asset = record["payload"] as? CKAsset, let file = asset.fileURL else {
              throw BackupError.invalidData
            }
            let data = try Data(contentsOf: file)
            value = ["date": try timestamp(record), "data": FlutterStandardTypedData(bytes: data)]
          } else {
            value = nil
          }
        default:
          value = FlutterMethodNotImplemented
        }
        await MainActor.run {
          self.busy = false
          result(value)
        }
      } catch {
        let code: String
        if case BackupError.unavailable = error {
          code = "unavailable"
        } else if let error = error as? CKError {
          switch error.code {
          case .notAuthenticated, .permissionFailure, .managedAccountRestricted: code = "unavailable"
          case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited: code = "network"
          case .quotaExceeded: code = "quota"
          case .serverRecordChanged: code = "conflict"
          default: code = "cloud_failure"
          }
        } else {
          code = "cloud_failure"
        }
        await MainActor.run {
          self.busy = false
          result(FlutterError(code: code, message: nil, details: nil))
        }
      }
    }
  }

  private func fetchRecord() async throws -> CKRecord? {
    do {
      return try await container.privateCloudDatabase.record(for: recordID)
    } catch let error as CKError where error.code == .unknownItem {
      return nil
    }
  }

  private func timestamp(_ record: CKRecord) throws -> Int64 {
    guard let date = record.modificationDate ?? (record["savedAt"] as? Date) else { throw BackupError.invalidData }
    return Int64(date.timeIntervalSince1970 * 1000)
  }

  private enum BackupError: Error {
    case unavailable
    case invalidData
  }
}
