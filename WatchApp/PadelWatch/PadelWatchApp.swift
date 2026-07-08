import SwiftUI
import PadelKit

@main
struct PadelWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @StateObject private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
            .environmentObject(connectivity)
            .environmentObject(store)
            // Tapping the watch-face complication launches the app with this URL;
            // jump straight into the scoreboard so points can be registered
            // without hunting through the menus.
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == PadelWatchDeepLink.scheme,
              url.host == PadelWatchDeepLink.scoreHost else { return }
        // Resume the current match or start a fresh quick one, then broadcast the
        // new match to the phone so both devices score the same game.
        if let newMatch = store.openScoring() {
            connectivity.send(.match(newMatch))
        }
    }
}

/// The custom URL the watch-face complication opens to jump into scoring. The
/// complication target can't link the app's sources, so it hard-codes the same
/// `padelwatch://score` string; this is the routing side that consumes it.
enum PadelWatchDeepLink {
    static let scheme = "padelwatch"
    static let scoreHost = "score"

    static var scoreURL: URL {
        URL(string: "\(scheme)://\(scoreHost)")!
    }
}
