import Foundation
import PadelKit

/// Lightweight on-watch persistence. The Watch app favors quick, glanceable
/// scoring over full history browsing (that lives on iPhone), so state is
/// just a couple of Codable blobs in UserDefaults rather than a full database.
@MainActor
final class WatchStore: ObservableObject {
    static let shared = WatchStore()

    @Published var activeMatch: MatchState? {
        didSet { save(activeMatch, key: Keys.activeMatch) }
    }
    @Published var activeAmericano: AmericanoSession? {
        didSet { save(activeAmericano, key: Keys.activeAmericano) }
    }
    @Published var recentMatches: [MatchState] = [] {
        didSet { save(recentMatches, key: Keys.recentMatches) }
    }

    /// A brand-new match that just arrived from the iPhone and should be opened
    /// on the watch automatically. The home view watches this, pushes the live
    /// scoreboard, and clears it. Transient — never persisted, so relaunching
    /// the watch app doesn't yank the user back into an old match.
    @Published var matchToPresent: MatchState?

    private enum Keys {
        static let activeMatch = "watch.activeMatch"
        static let activeAmericano = "watch.activeAmericano"
        static let recentMatches = "watch.recentMatches"
    }

    private init() {
        activeMatch = load(Keys.activeMatch)
        activeAmericano = load(Keys.activeAmericano)
        recentMatches = load(Keys.recentMatches) ?? []
    }

    /// Adopts a match pushed from the iPhone. Live score updates to the match
    /// we're already tracking flow through the scoreboard view (which also plays
    /// a haptic), so we only step in for a *new* match: it becomes active and is
    /// flagged for the watch to open automatically.
    func adoptIncomingMatch(_ state: MatchState) {
        guard activeMatch?.id != state.id else { return }
        activeMatch = state
        if !state.isFinished {
            matchToPresent = state
        }
    }

    /// Adopts an Americano session pushed from the iPhone. As with matches, live
    /// updates to the current session are handled by the round view, so we only
    /// take over when a different session arrives.
    func adoptIncomingAmericano(_ session: AmericanoSession) {
        guard activeAmericano?.id != session.id else { return }
        activeAmericano = session
    }

    /// Clears whatever is active — used when the iPhone signals the shared
    /// session has ended.
    func clearActiveSessions() {
        activeMatch = nil
        activeAmericano = nil
        matchToPresent = nil
    }

    func archiveMatchIfFinished() {
        guard let activeMatch, activeMatch.isFinished else { return }
        recentMatches.removeAll { $0.id == activeMatch.id }
        recentMatches.insert(activeMatch, at: 0)
        if recentMatches.count > 10 { recentMatches.removeLast() }
    }

    private func save<T: Codable>(_ value: T?, key: String) {
        guard let value else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set((try? JSONEncoder().encode(value)) ?? Data(), forKey: key)
    }

    private func load<T: Codable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
