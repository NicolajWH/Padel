import ActivityKit
import Foundation

/// The Live Activity contract shared between the app (which starts/updates
/// the activity) and the PadelWidgets extension (which renders it on the
/// lock screen and in the Dynamic Island). Plain value types only — the
/// widget extension doesn't link PadelKit.
struct MatchActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Display labels: "0"/"15"/"30"/"40"/"Ad", or tiebreak points.
        var pointsA: String
        var pointsB: String
        var gamesA: Int
        var gamesB: Int
        var setsA: Int
        var setsB: Int
        var showSets: Bool
        var teamAServing: Bool
        var isTiebreak: Bool
        var isFinished: Bool
        /// "" while playing, winner line when finished.
        var statusText: String
    }

    var matchID: UUID
    var teamAName: String
    var teamBName: String
}
