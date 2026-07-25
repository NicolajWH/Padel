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
    case workoutAutoEnd(WorkoutAutoEndSettings)
}

/// Safety settings shared by the phone and Watch. The Watch owns the HealthKit
/// workout, while the larger phone screen is the natural place to configure it.
public struct WorkoutAutoEndSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var durationMinutes: Int

    public init(isEnabled: Bool = true, durationMinutes: Int = 360) {
        self.isEnabled = isEnabled
        self.durationMinutes = durationMinutes
    }
}

/// The players configured on the companion iPhone. Keeping this in PadelKit
/// lets the phone send the exact same `Player` values that the Watch uses when
/// it creates a match, including stable ids and colours.
public struct PlayerRoster: Codable, Hashable, Sendable {
    public var players: [Player]
    public var ownerID: UUID?

    public init(players: [Player], ownerID: UUID? = nil) {
        self.players = players
        self.ownerID = ownerID
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
