import Foundation

public struct Team: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// Padel is always played in doubles, so a team is exactly two players.
    public var players: [Player]

    public init(id: UUID = UUID(), players: [Player]) {
        self.id = id
        self.players = players
    }

    public var displayName: String {
        players.map { $0.name }.joined(separator: " & ")
    }
}

public enum TeamSide: String, Codable, Sendable, CaseIterable, Identifiable {
    case teamA
    case teamB

    public var id: String { rawValue }

    public var opposite: TeamSide { self == .teamA ? .teamB : .teamA }
}
