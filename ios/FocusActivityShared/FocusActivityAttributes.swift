import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct FocusActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String
  }

  var taskId: String
  var startedAt: Date
}
