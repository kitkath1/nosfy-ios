import ActivityKit
import SwiftUI
import WidgetKit

/// Chronos système et transitions sur les faits du player, sans horloge d'app.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLiveCard(state: context.state, startedAt: context.attributes.startedAt,
                            stale: context.isStale)
                .widgetURL(context.attributes.sessionURL)
                .activityBackgroundTint(Color(red: 0.016, green: 0.016, blue: 0.024))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutLivePortrait()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutLiveClock(state: context.state, startedAt: context.attributes.startedAt)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        WorkoutLiveDetails(state: context.state, stale: context.isStale)
                        WorkoutLiveProgress(focus: context.state.focus,
                                            english: context.state.language == "en")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                WorkoutLiveMoon(focus: context.state.focus, size: 22)
            } compactTrailing: {
                WorkoutLiveClock(state: context.state, startedAt: context.attributes.startedAt)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(width: 58)
            } minimal: {
                WorkoutLiveMoon(focus: context.state.focus, size: 22)
            }
            .widgetURL(context.attributes.sessionURL)
            .keylineTint(WorkoutLiveMoon.amber)
        }
    }
}
