import SwiftUI
import SwiftData
import PadelKit

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationProvider = LocationProvider()
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]
    @AppStorage("profileName") private var profileName = ""

    var body: some View {
        TabView {
            NavigationStack { PlayHomeView() }
                .tabItem { Label("Play", systemImage: "tennis.racket") }

            NavigationStack { AmericanoHomeView() }
                .tabItem { Label("Mix", systemImage: "person.3.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack { PlayersView() }
                .tabItem { Label("Players", systemImage: "person.crop.circle") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            syncPlayerRoster()
            await refreshPresence()
        }
        .onChange(of: rosterFingerprint) { _, _ in syncPlayerRoster() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshPresence() }
            }
        }
    }

    private var rosterFingerprint: String {
        ([profileName] + savedPlayers.map { "\($0.id):\($0.name):\($0.colorHex)" })
            .joined(separator: "|")
    }

    private func syncPlayerRoster() {
        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = name.isEmpty ? nil : Player(name: name)
        connectivity.sendPlayerRoster(PlayerRoster(owner: owner, savedPlayers: savedPlayers.map(\.asPlayer)))
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
