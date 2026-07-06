import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PadelWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MatchLiveActivity()
    }
}

/// Live score on the lock screen and in the Dynamic Island while a match is
/// being scored in the app (or from the Watch, relayed by the phone).
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            LockScreenScoreView(context: context)
                .padding(14)
                .activityBackgroundTint(Theme.night)
                .activitySystemActionForegroundColor(Theme.lime)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TeamLine(
                        name: context.attributes.teamAName,
                        points: context.state.pointsA,
                        isServing: context.state.teamAServing && !context.state.isFinished,
                        color: Theme.teamA
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamLine(
                        name: context.attributes.teamBName,
                        points: context.state.pointsB,
                        isServing: !context.state.teamAServing && !context.state.isFinished,
                        color: Theme.teamB
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GamesAndSetsLine(state: context.state)
                }
            } compactLeading: {
                Text(context.state.pointsA)
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(Theme.teamA)
            } compactTrailing: {
                Text(context.state.pointsB)
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(Theme.teamB)
            } minimal: {
                Image(systemName: "figure.tennis")
                    .foregroundStyle(Theme.lime)
            }
        }
    }
}

private struct LockScreenScoreView: View {
    let context: ActivityViewContext<MatchActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TeamLine(
                    name: context.attributes.teamAName,
                    points: context.state.pointsA,
                    isServing: context.state.teamAServing && !context.state.isFinished,
                    color: Theme.teamA
                )
                Spacer()
                TeamLine(
                    name: context.attributes.teamBName,
                    points: context.state.pointsB,
                    isServing: !context.state.teamAServing && !context.state.isFinished,
                    color: Theme.teamB
                )
            }
            GamesAndSetsLine(state: context.state)
        }
        .foregroundStyle(.white)
    }
}

private struct TeamLine: View {
    let name: String
    let points: String
    let isServing: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if isServing {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.lime)
                }
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Text(points)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct GamesAndSetsLine: View {
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            if state.isFinished {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.lime)
                Text(state.statusText)
                    .font(.caption.bold())
            } else {
                Text("Games \(state.gamesA)–\(state.gamesB)")
                    .font(.caption)
                if state.showSets {
                    Text("· Sets \(state.setsA)–\(state.setsB)")
                        .font(.caption)
                }
                if state.isTiebreak {
                    Text("· Tiebreak")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.lime)
                }
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }
}

/// Mirrors PadelTheme in the main app (the extension doesn't link it).
private enum Theme {
    static let teamA = Color(red: 0x4D / 255, green: 0xA3 / 255, blue: 0xFF / 255)
    static let teamB = Color(red: 0xFF / 255, green: 0x7A / 255, blue: 0x59 / 255)
    static let lime = Color(red: 0xC6 / 255, green: 0xED / 255, blue: 0x3F / 255)
    static let night = Color(red: 0x07 / 255, green: 0x1A / 255, blue: 0x30 / 255)
}
