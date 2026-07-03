import Foundation

/// Configurable rules for a single padel match. Defaults mirror the most common
/// club/tournament ruleset used on court.
public struct MatchSettings: Codable, Hashable, Sendable {
    /// If true, games are decided by "golden point" sudden-death at 40-40 instead of advantage.
    public var goldenPoint: Bool
    /// Number of sets a team must win (1 = single set, 2 = best of 3).
    public var setsToWin: Int
    /// Games needed to win a set (usually 6).
    public var gamesPerSet: Int
    /// Whether a set must be won by two games (triggers a tiebreak at gamesPerSet-gamesPerSet).
    public var winByTwoGames: Bool
    /// Points needed to win a regular set tiebreak (usually 7, win by 2).
    public var tiebreakPoints: Int
    /// If true, the deciding set is replaced by a single match tiebreak instead of a full set.
    public var finalSetIsMatchTiebreak: Bool
    /// Points needed to win the match tiebreak (usually 10, win by 2).
    public var matchTiebreakPoints: Int

    public init(
        goldenPoint: Bool = false,
        setsToWin: Int = 2,
        gamesPerSet: Int = 6,
        winByTwoGames: Bool = true,
        tiebreakPoints: Int = 7,
        finalSetIsMatchTiebreak: Bool = false,
        matchTiebreakPoints: Int = 10
    ) {
        self.goldenPoint = goldenPoint
        self.setsToWin = setsToWin
        self.gamesPerSet = gamesPerSet
        self.winByTwoGames = winByTwoGames
        self.tiebreakPoints = tiebreakPoints
        self.finalSetIsMatchTiebreak = finalSetIsMatchTiebreak
        self.matchTiebreakPoints = matchTiebreakPoints
    }

    public static let standard = MatchSettings()

    public static let goldenPointBestOf3 = MatchSettings(goldenPoint: true)

    public static let quickSingleSet = MatchSettings(setsToWin: 1)

    public static let proWithMatchTiebreak = MatchSettings(finalSetIsMatchTiebreak: true)
}
