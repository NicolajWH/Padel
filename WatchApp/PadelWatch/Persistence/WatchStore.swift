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
