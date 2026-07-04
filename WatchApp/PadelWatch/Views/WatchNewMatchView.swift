import SwiftUI
import PadelKit

struct WatchNewMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var goldenPoint = false
    @State private var singleSet = true
    @State private var navigate = false

    var body: some View {
        Form {
            Toggle("Golden Point", isOn: $goldenPoint)
            Toggle("Single Set", isOn: $singleSet)

            Button("Start") {
                start()
            }
        }
        .navigationTitle("New Match")
        .navigationDestination(isPresented: $navigate) {
            WatchLiveMatchView()
        }
    }

    private func start() {
        let teamA = Team(players: [Player(name: "Team A-1"), Player(name: "Team A-2")])
        let teamB = Team(players: [Player(name: "Team B-1"), Player(name: "Team B-2")])
        let settings = MatchSettings(goldenPoint: goldenPoint, setsToWin: singleSet ? 1 : 2)
        let state = MatchState(teamA: teamA, teamB: teamB, settings: settings)
        store.activeMatch = state
        connectivity.send(.match(state))
        navigate = true
    }
}

#Preview {
    NavigationStack { WatchNewMatchView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
