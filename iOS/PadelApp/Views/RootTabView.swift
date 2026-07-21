import SwiftUI
import SwiftData
import PadelKit

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationProvider = LocationProvider()
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @Query(sort: \SavedPlayerRecord.name) private var savedPlayers: [SavedPlayerRecord]
    @AppStorage(UserProfile.nameKey) private var profileName = ""

    var body: some View {
        TabView {
            NavigationStack { PlayHomeView() }
                .tabItem { Label("Spil", systemImage: "tennis.racket") }

            NavigationStack { AmericanoHomeView() }
                .tabItem { Label("Mix", systemImage: "person.3.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("Historik", systemImage: "clock.arrow.circlepath") }

            NavigationStack { PlayersView() }
                .tabItem { Label("Spillere", systemImage: "person.crop.circle") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Indstillinger", systemImage: "gearshape") }
        }
        .tint(.accentColor)
        .task {
            syncPlayerRoster()
            await refreshPresence()
        }
        .onChange(of: savedPlayers.map(\.asPlayer)) { _, _ in syncPlayerRoster() }
        .onChange(of: profileName) { _, _ in syncPlayerRoster() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshPresence() }
            }
        }
    }

    private func syncPlayerRoster() {
        var players = savedPlayers.map(\.asPlayer)
        let ownerName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        var ownerID: UUID?
        if !ownerName.isEmpty {
            if let savedOwner = players.first(where: { PlayerKey.normalize($0.name) == PlayerKey.normalize(ownerName) }) {
                ownerID = savedOwner.id
            } else {
                let owner = Player(id: UserProfile.watchPlayerID, name: ownerName)
                players.insert(owner, at: 0)
                ownerID = owner.id
            }
        }
        connectivity.send(.playerRoster(PlayerRoster(players: players, ownerID: ownerID)))
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
