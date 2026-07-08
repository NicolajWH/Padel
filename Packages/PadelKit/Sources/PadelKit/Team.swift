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

    /// A compact form using each player's initials (e.g. "NW & AB"). Used where
    /// space is tight — the watch face and the Live Activity — so full names
    /// don't wrap and push controls off-screen.
    public var shortDisplayName: String {
        players.map { $0.initials }.joined(separator: " & ")
    }
}

public enum TeamSide: String, Codable, Sendable, CaseIterable, Identifiable {
    case teamA
    case teamB

    public var id: String { rawValue }

    public var opposite: TeamSide { self == .teamA ? .teamB : .teamA }
}
