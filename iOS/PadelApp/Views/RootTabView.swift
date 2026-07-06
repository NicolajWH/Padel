import SwiftUI

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationProvider = LocationProvider()

    var body: some View {
        TabView {
            NavigationStack { PlayHomeView() }
                .tabItem { Label("Play", systemImage: "tennis.racket") }

            NavigationStack { AmericanoHomeView() }
                .tabItem { Label("Americano", systemImage: "person.3.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack { PlayersView() }
                .tabItem { Label("Players", systemImage: "person.crop.circle") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            await refreshPresence()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshPresence() }
            }
        }
    }

    /// Quietly tells nearby players "I'm here" whenever the app comes to
    /// the foreground, so match setup on their phones can suggest this
    /// player. Never prompts — does nothing until the user has granted
    /// location access elsewhere (e.g. by joining or sharing a match).
    private func refreshPresence() async {
        guard NearbyPlayersService.isDiscoveryEnabled, !UserProfile.name.isEmpty,
              let location = await locationProvider.currentLocationIfAuthorized() else { return }
        await NearbyPlayersService.publish(name: UserProfile.name, location: location)
    }
}

#Preview {
    RootTabView()
}
