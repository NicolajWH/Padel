import Foundation

public struct SetScore: Codable, Hashable, Sendable {
    public var teamAGames: Int
    public var teamBGames: Int
    /// True when this set was decided by a match tiebreak rather than played out as a full set.
    public var wasMatchTiebreak: Bool

    public init(teamAGames: Int, teamBGames: Int, wasMatchTiebreak: Bool = false) {
        self.teamAGames = teamAGames
        self.teamBGames = teamBGames
        self.wasMatchTiebreak = wasMatchTiebreak
    }
}

/// A fully derived, point-in-time view of a match. Always computed from a `MatchSettings`
/// plus the ordered log of points won — never stored/mutated independently, so it can
/// never drift out of sync with the log (and undo is simply "drop the last log entry").
public struct MatchSnapshot: Codable, Hashable, Sendable {
    public var completedSets: [SetScore]
    public var currentSetGamesA: Int
    public var currentSetGamesB: Int
    public var gamePointLabelA: String
    public var gamePointLabelB: String
    public var isTiebreak: Bool
    public var isMatchTiebreak: Bool
    public var tiebreakPointsA: Int
    public var tiebreakPointsB: Int
    public var servingSide: TeamSide
    public var servingPlayerIndex: Int
    public var setsWonA: Int
    public var setsWonB: Int
    public var isMatchOver: Bool
    public var winner: TeamSide?
}

public enum MatchEngine {

    /// Pure function: given the rules and the full history of points, derive the current
    /// state of the match. This is the single source of truth for all scoring logic.
    public static func simulate(settings: MatchSettings, firstServer: TeamSide = .teamA, pointLog: [TeamSide]) -> MatchSnapshot {
        var completedSets: [SetScore] = []
        var gamesA = 0, gamesB = 0
        var ptsA = 0, ptsB = 0
        var tieA = 0, tieB = 0
        var inTiebreak = false
        var inMatchTiebreak = false
        var setsWonA = 0, setsWonB = 0
        var winner: TeamSide?
        var currentServer = firstServer
        var serveCountA = 0
        var serveCountB = 0

        let setsNeeded = max(1, settings.setsToWin)
        let gamesNeeded = max(1, settings.gamesPerSet)

        func advanceServer() {
            if currentServer == .teamA { serveCountA += 1 } else { serveCountB += 1 }
            currentServer = currentServer.opposite
        }

        for point in pointLog {
            if winner != nil { break }

            if inTiebreak {
                if point == .teamA { tieA += 1 } else { tieB += 1 }
                let target = inMatchTiebreak ? settings.matchTiebreakPoints : settings.tiebreakPoints
                let leader = max(tieA, tieB)
                let diff = abs(tieA - tieB)
                if leader >= target && diff >= 2 {
                    if tieA > tieB { gamesA += 1 } else { gamesB += 1 }
                    completedSets.append(SetScore(teamAGames: gamesA, teamBGames: gamesB, wasMatchTiebreak: inMatchTiebreak))
                    if tieA > tieB { setsWonA += 1 } else { setsWonB += 1 }
                    gamesA = 0; gamesB = 0
                    tieA = 0; tieB = 0
                    inTiebreak = false
                    inMatchTiebreak = false
                    advanceServer()

                    if setsWonA == setsNeeded { winner = .teamA }
                    else if setsWonB == setsNeeded { winner = .teamB }
                }
                continue
            }

            if point == .teamA { ptsA += 1 } else { ptsB += 1 }

            let gameWon: TeamSide?
            if settings.goldenPoint {
                if ptsA >= 4 && ptsA - ptsB >= 1 { gameWon = .teamA }
                else if ptsB >= 4 && ptsB - ptsA >= 1 { gameWon = .teamB }
                else { gameWon = nil }
            } else {
                if ptsA >= 4 && ptsA - ptsB >= 2 { gameWon = .teamA }
                else if ptsB >= 4 && ptsB - ptsA >= 2 { gameWon = .teamB }
                else { gameWon = nil }
            }

            if let gameWon {
                if gameWon == .teamA { gamesA += 1 } else { gamesB += 1 }
                ptsA = 0; ptsB = 0
                advanceServer()

                if gamesA >= gamesNeeded || gamesB >= gamesNeeded {
                    if abs(gamesA - gamesB) >= 2 || !settings.winByTwoGames {
                        completedSets.append(SetScore(teamAGames: gamesA, teamBGames: gamesB))
                        if gamesA > gamesB { setsWonA += 1 } else { setsWonB += 1 }
                        gamesA = 0; gamesB = 0

                        if setsWonA == setsNeeded { winner = .teamA }
                        else if setsWonB == setsNeeded { winner = .teamB }
                    } else if gamesA == gamesNeeded && gamesB == gamesNeeded {
                        let isDecidingSet = setsWonA == setsNeeded - 1 && setsWonB == setsNeeded - 1
                        inTiebreak = true
                        inMatchTiebreak = isDecidingSet && settings.finalSetIsMatchTiebreak
                    }
                }
            }
        }

        func label(for pts: Int, opponent: Int) -> String {
            if settings.goldenPoint {
                switch pts {
                case 0: return "0"
                case 1: return "15"
                case 2: return "30"
                default: return "40"
                }
            } else {
                if pts >= 3 && opponent >= 3 {
                    if pts == opponent { return "40" }
                    return pts > opponent ? "AD" : "40"
                }
                switch pts {
                case 0: return "0"
                case 1: return "15"
                case 2: return "30"
                default: return "40"
                }
            }
        }

        let labelA = winner == nil ? label(for: ptsA, opponent: ptsB) : ""
        let labelB = winner == nil ? label(for: ptsB, opponent: ptsA) : ""

        // The loop keeps `currentServer` fixed on the game-by-game server. Inside
        // a tiebreak the serve isn't tracked that way: the first server serves a
        // single point, then serve alternates every two points. Derive the live
        // server from how many tiebreak points have been played, keeping the two
        // players on each team in their established alternating order.
        let servingSide: TeamSide
        let servingPlayerIndex: Int
        if inTiebreak {
            let pointsPlayed = tieA + tieB
            let serviceTurn = (pointsPlayed + 1) / 2
            let side = serviceTurn % 2 == 0 ? currentServer : currentServer.opposite
            let baseGames = side == .teamA ? serveCountA : serveCountB
            servingSide = side
            servingPlayerIndex = (baseGames + serviceTurn / 2) % 2
        } else {
            servingSide = currentServer
            servingPlayerIndex = (currentServer == .teamA ? serveCountA : serveCountB) % 2
        }

        return MatchSnapshot(
            completedSets: completedSets,
            currentSetGamesA: gamesA,
            currentSetGamesB: gamesB,
            gamePointLabelA: labelA,
            gamePointLabelB: labelB,
            isTiebreak: inTiebreak,
            isMatchTiebreak: inMatchTiebreak,
            tiebreakPointsA: tieA,
            tiebreakPointsB: tieB,
            servingSide: servingSide,
            servingPlayerIndex: servingPlayerIndex,
            setsWonA: setsWonA,
            setsWonB: setsWonB,
            isMatchOver: winner != nil,
            winner: winner
        )
    }
}
