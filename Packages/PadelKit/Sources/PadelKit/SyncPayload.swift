import Foundation

/// Messages exchanged between the iPhone and Watch apps over WatchConnectivity.
/// Kept platform-agnostic here (no `WatchConnectivity` import) so it stays
/// testable and usable from both targets; each target's connectivity manager
/// is responsible for actually sending/receiving these.
public enum SyncPayload: Codable, Sendable {
    case match(MatchState)
    case americano(AmericanoSession)
    case matchFinished(MatchState)
    case americanoFinished(AmericanoSession)
    case requestLatest
    case clearActiveSession
    case playerRoster(PlayerRoster)
}

/// The players configured on iPhone and made available for quick selection on
/// Apple Watch. The profile owner is separate so the watch can always identify
/// "you" without relying on a hard-coded label.
public struct PlayerRoster: Codable, Hashable, Sendable {
    public var owner: Player?
    public var savedPlayers: [Player]

    public init(owner: Player?, savedPlayers: [Player]) {
        self.owner = owner
        self.savedPlayers = savedPlayers
    }

    public var allPlayers: [Player] {
        var seen = Set<String>()
        return ([owner].compactMap { $0 } + savedPlayers).filter {
            seen.insert(PlayerKey.normalize($0.name)).inserted
        }
    }
}

public extension SyncPayload {
    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> SyncPayload? {
        try? JSONDecoder().decode(SyncPayload.self, from: data)
    }
}
