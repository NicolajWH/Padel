import SwiftUI

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
        }
    }
}
