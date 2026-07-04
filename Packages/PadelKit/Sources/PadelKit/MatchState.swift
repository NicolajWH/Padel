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
        settings: MatchSettings = .standard,
        teamA: Team,
        teamB: Team,
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
}
