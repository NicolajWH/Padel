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
}

public extension SyncPayload {
    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> SyncPayload? {
        try? JSONDecoder().decode(SyncPayload.self, from: data)
    }
}
