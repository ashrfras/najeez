import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FocusActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 18.0, *) {
      return WatchFocusActivityWidget()
    } else {
      return FocusActivityWidget()
    }
  }
}

@available(iOS 18.0, *)
struct WatchFocusActivityWidget: Widget {
  var body: some WidgetConfiguration {
    FocusActivityWidget().body.supplementalActivityFamilies([.small])
  }
}

struct FocusActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FocusActivityAttributes.self) { context in
      if #available(iOS 18.0, *) {
        AdaptiveFocusView(context: context)
      } else {
        FocusContent(context: context, compact: false)
      }
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("قيد التركيز", systemImage: "scope")
        }
        DynamicIslandExpandedRegion(.trailing) {
          FocusTimer(start: context.attributes.startedAt)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.title).font(.headline).lineLimit(2)
            .environment(\.layoutDirection, .rightToLeft)
        }
      } compactLeading: {
        Image(systemName: "scope").foregroundStyle(.cyan)
      } compactTrailing: {
        FocusTimer(start: context.attributes.startedAt)
          .font(.caption2).frame(width: 62)
      } minimal: {
        Image(systemName: "scope").foregroundStyle(.cyan)
      }
      .keylineTint(.cyan)
    }
  }
}

@available(iOS 18.0, *)
private struct AdaptiveFocusView: View {
  @Environment(\.activityFamily) private var family
  let context: ActivityViewContext<FocusActivityAttributes>

  var body: some View {
    FocusContent(context: context, compact: family == .small)
  }
}

private struct FocusContent: View {
  let context: ActivityViewContext<FocusActivityAttributes>
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 4 : 8) {
      Label("قيد التركيز", systemImage: "scope")
        .font(.caption).foregroundStyle(.cyan)
      Text(context.state.title)
        .font(compact ? .subheadline : .headline).lineLimit(compact ? 1 : 2)
      FocusTimer(start: context.attributes.startedAt)
        .font(compact ? .title3 : .title2)
    }
    .padding(compact ? 10 : 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .environment(\.layoutDirection, .rightToLeft)
    .activityBackgroundTint(Color(red: 0.05, green: 0.07, blue: 0.10))
    .activitySystemActionForegroundColor(.white)
  }
}

private struct FocusTimer: View {
  let start: Date

  var body: some View {
    // The system renders elapsed time even while Flutter is suspended.
    Text(start, style: .timer)
      .monospacedDigit()
      .environment(\.layoutDirection, .leftToRight)
      .accessibilityLabel("الوقت المنقضي")
  }
}

@available(iOS 18.0, *)
#Preview("Focus", as: .content, using: FocusActivityAttributes(
  taskId: "preview", startedAt: Date().addingTimeInterval(-3720))) {
  WatchFocusActivityWidget()
} contentStates: {
  FocusActivityAttributes.ContentState(title: "قراءة الفصل الأول")
  FocusActivityAttributes.ContentState(title: "مراجعة خطة المشروع والتعديلات المطلوبة")
}
