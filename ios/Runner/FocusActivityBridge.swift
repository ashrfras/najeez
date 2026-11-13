import ActivityKit
import Flutter
import UIKit

/// Calls are serialized by Flutter; no push tokens, timers, or shared database.
final class FocusActivityBridge {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "sync" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
      return
    }
    Task { @MainActor in
      let taskId = arguments["taskId"] as? String
      let title = arguments["title"] as? String
      let milliseconds = arguments["startedAt"] as? NSNumber
      let start = milliseconds.map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
      var existing: Activity<FocusActivityAttributes>?
      for activity in Activity<FocusActivityAttributes>.activities {
        if let taskId, let start,
           activity.attributes.taskId == taskId,
           abs(activity.attributes.startedAt.timeIntervalSince(start)) < 0.001,
           activity.activityState == .active, existing == nil {
          existing = activity
        } else {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
      guard let taskId, let title, let start else {
        result(nil)
        return
      }
      let content = ActivityContent(
        state: FocusActivityAttributes.ContentState(title: title), staleDate: nil)
      if let existing {
        if existing.content.state != content.state { await existing.update(content) }
        result(nil)
        return
      }
      // Do not recreate dismissed or expired presentations for the same session.
      let key = "focusActivity.lastRequestedSession"
      let sessionKey = "\(taskId):\(milliseconds!.int64Value)"
      guard UserDefaults.standard.string(forKey: key) != sessionKey,
            Date().timeIntervalSince(start) < 8 * 60 * 60,
            UIApplication.shared.applicationState == .active,
            ActivityAuthorizationInfo().areActivitiesEnabled else {
        result(nil)
        return
      }
      do {
        _ = try Activity.request(
          attributes: FocusActivityAttributes(taskId: taskId, startedAt: start),
          content: content, pushType: nil)
        UserDefaults.standard.set(sessionKey, forKey: key)
        result(nil)
      } catch {
        result(FlutterError(code: "activity_request_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
