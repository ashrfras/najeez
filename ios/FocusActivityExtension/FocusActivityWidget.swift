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
        DynamicIslandExpandedRegion(.bottom) {
          // A shared RTL container controls the whole row, independently of
          // the system direction used to place the Island's separate regions.
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Label("قيد التركيز", systemImage: "scope")
                .foregroundStyle(.cyan)
              Spacer(minLength: 12)
              FocusTimer(start: context.attributes.startedAt)
                .multilineTextAlignment(.leading)
                .frame(width: 100)
            }
            Text(context.state.title).font(.headline).lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .environment(\.layoutDirection, .rightToLeft)
        }
      } compactLeading: {
        Image(systemName: "scope").foregroundStyle(.cyan)
      } compactTrailing: {
        FocusTimer(start: context.attributes.startedAt)
          // Bound the flexible timer without reserving excess compact width.
          .font(.caption2)
          .multilineTextAlignment(.trailing)
          .frame(width: 46)
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
    // The small presentation needs its own inset inside the rounded card.
    .padding(.top, compact ? 18 : 16)
    .padding(.horizontal, compact ? 10 : 16)
    .padding(.bottom, compact ? 18 : 16)
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
      // Also localizes the system's coarse time units in Always On mode.
      .environment(\.locale, Locale(identifier: "ar"))
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
