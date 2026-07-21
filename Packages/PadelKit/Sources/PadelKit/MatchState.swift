import Foundation

/// A single padel match in progress or completed. Scoring history is kept as an
/// append-only log of point winners, so the visible score is always re-derived
/// (see `MatchEngine`) and undo is trivially correct.
public struct MatchState: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var settings: MatchSettings
    public var teamA: Team
    public var teamB: Team
    public var firstServer: TeamSide
    public var pointLog: [TeamSide]
    public var createdAt: Date
    public var title: String

    public init(
        id: UUID = UUID(),
        teamA: Team,
        teamB: Team,
        settings: MatchSettings = .standard,
        firstServer: TeamSide = .teamA,
        pointLog: [TeamSide] = [],
        createdAt: Date = Date(),
        title: String = "Match"
    ) {
        self.id = id
        self.settings = settings
        self.teamA = teamA
        self.teamB = teamB
        self.firstServer = firstServer
        self.pointLog = pointLog
        self.createdAt = createdAt
        self.title = title
    }

    public var snapshot: MatchSnapshot {
        MatchEngine.simulate(settings: settings, firstServer: firstServer, pointLog: pointLog)
    }

    public var isFinished: Bool { snapshot.isMatchOver }

    public mutating func addPoint(for side: TeamSide) {
        guard !snapshot.isMatchOver else { return }
        pointLog.append(side)
    }

    public mutating func undoLastPoint() {
        guard !pointLog.isEmpty else { return }
        pointLog.removeLast()
    }

    public func team(_ side: TeamSide) -> Team {
        side == .teamA ? teamA : teamB
    }

    /// The player currently holding serve, derived from the same game and
    /// tiebreak rotation as the scoreboard.
    public var currentServingPlayer: Player? {
        let snap = snapshot
        let players = team(snap.servingSide).players
        guard players.indices.contains(snap.servingPlayerIndex) else { return nil }
        return players[snap.servingPlayerIndex]
    }

    /// Corrects the live server without changing the score. This is useful on
    /// court when the originally selected server was wrong or the players have
    /// agreed on a different service order.
    public mutating func setCurrentServer(playerID: UUID) {
        let desiredSide: TeamSide
        if teamA.players.contains(where: { $0.id == playerID }) {
            desiredSide = .teamA
        } else if teamB.players.contains(where: { $0.id == playerID }) {
            desiredSide = .teamB
        } else {
            return
        }

        if snapshot.servingSide != desiredSide {
            firstServer = firstServer.opposite
        }

        let serverIndex = snapshot.servingPlayerIndex
        if desiredSide == .teamA,
           let playerIndex = teamA.players.firstIndex(where: { $0.id == playerID }),
           teamA.players.indices.contains(serverIndex) {
            teamA.players.swapAt(playerIndex, serverIndex)
        } else if desiredSide == .teamB,
                  let playerIndex = teamB.players.firstIndex(where: { $0.id == playerID }),
                  teamB.players.indices.contains(serverIndex) {
            teamB.players.swapAt(playerIndex, serverIndex)
        }
    }
}
