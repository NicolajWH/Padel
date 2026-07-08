import SwiftUI
import WidgetKit

@main
struct PadelWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScoreLauncherComplication()
    }
}

/// A watch-face complication that opens straight into the padel scoreboard so a
/// point can be registered without digging through the app. Tapping deep-links
/// via `padelwatch://score`, which the app routes to the live match — resuming
/// the one in progress, or starting a fresh quick match.
struct ScoreLauncherComplication: Widget {
    private let kind = "PadelScoreLauncher"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LauncherProvider()) { _ in
            ComplicationView()
                // Mirrors PadelWatchDeepLink in the Watch app (the extension
                // doesn't link the app's sources).
                .widgetURL(URL(string: "padelwatch://score"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Score Padel")
        .description("Tap to jump straight into scoring a padel match.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

/// The complication is a fixed launcher, so the timeline is a single static
/// entry that never needs refreshing.
private struct LauncherProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
    }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Score", systemImage: "tennisball.fill")

        case .accessoryCorner:
            Image(systemName: "tennisball.fill")
                .font(.title2)
                .foregroundStyle(WidgetTheme.lime)
                .widgetLabel("Padel")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(WidgetTheme.lime)
                    Text("Score")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "tennisball.fill")
                    .font(.title3)
                    .foregroundStyle(WidgetTheme.lime)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Padel")
                        .font(.headline)
                    Text("Tap to score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

        default:
            Image(systemName: "tennisball.fill")
                .foregroundStyle(WidgetTheme.lime)
        }
    }
}

/// Mirrors PadelTheme in the Watch app (the extension doesn't link it).
private enum WidgetTheme {
    static let lime = Color(red: 0xE3 / 255, green: 0xC3 / 255, blue: 0x6B / 255)
}
