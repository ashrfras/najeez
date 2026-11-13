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
        FocusContent(context: context)
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
    if family == .small {
      WatchFocusContent(title: context.state.title, start: context.attributes.startedAt)
    } else {
      FocusContent(context: context)
    }
  }
}

private struct WatchFocusContent: View {
  let title: String
  let start: Date

  var body: some View {
    // Smart Stack cards are only about 70–82pt tall. Keep two rows inside
    // the proposed height instead of overflowing a padded three-row layout.
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Label("قيد التركيز", systemImage: "scope")
          .font(.caption2).foregroundStyle(.cyan)
          .fixedSize(horizontal: true, vertical: false)
        FocusTimer(start: start)
          .font(.subheadline.monospacedDigit())
          .multilineTextAlignment(.leading)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      Text(title)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .multilineTextAlignment(.leading)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .environment(\.layoutDirection, .rightToLeft)
    .activityBackgroundTint(Color(red: 0.05, green: 0.07, blue: 0.10))
    .activitySystemActionForegroundColor(.white)
  }
}

private struct FocusContent: View {
  let context: ActivityViewContext<FocusActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("قيد التركيز", systemImage: "scope")
        .font(.caption).foregroundStyle(.cyan)
      Text(context.state.title)
        .font(.headline).lineLimit(2)
      FocusTimer(start: context.attributes.startedAt)
        .font(.title2)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .environment(\.layoutDirection, .rightToLeft)
    .activityBackgroundTint(Color(red: 0.05, green: 0.07, blue: 0.10))
    .activitySystemActionForegroundColor(.white)
  }
}

#Preview("Smart Stack — 40mm") {
  WatchFocusContent(title: "مراجعة خطة المشروع والتعديلات المطلوبة",
                    start: Date().addingTimeInterval(-3720))
    .frame(width: 152, height: 69.5)
    .background(.black, in: RoundedRectangle(cornerRadius: 18))
    .foregroundStyle(.white)
}

#Preview("Smart Stack — 49mm") {
  WatchFocusContent(title: "قراءة الفصل الأول",
                    start: Date().addingTimeInterval(-120))
    .frame(width: 198, height: 81.5)
    .background(.black, in: RoundedRectangle(cornerRadius: 18))
    .foregroundStyle(.white)
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
