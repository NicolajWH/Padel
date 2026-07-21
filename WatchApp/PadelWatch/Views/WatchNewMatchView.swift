import SwiftUI
import WatchKit
import PadelKit

struct WatchNewMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    @State private var players: [Player]
    @State private var partnerID: UUID
    @State private var firstServerID: UUID
    @State private var matchStarted = false

    init() {
        let defaults = [
            Player(name: String(localized: "Me")),
            Player(name: String(localized: "Player 2")),
            Player(name: String(localized: "Player 3")),
            Player(name: String(localized: "Player 4"))
        ]
        _players = State(initialValue: defaults)
        _partnerID = State(initialValue: defaults[1].id)
        _firstServerID = State(initialValue: defaults[0].id)
    }

    var body: some View {
        Form {
            Section("Players") {
                ForEach($players) { $player in
                    TextField("Name", text: $player.name)
                }
            }

            Section("Setup") {
                Picker("My Partner", selection: $partnerID) {
                    ForEach(players.dropFirst()) { player in
                        Text(player.name).tag(player.id)
                    }
                }
                Picker("First Server", selection: $firstServerID) {
                    ForEach(players) { player in
                        Text(player.name).tag(player.id)
                    }
                }
            }

            Button("Start Match") { startMatch() }
                .disabled(players.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
        .navigationTitle("New Match")
        .navigationDestination(isPresented: $matchStarted) {
            WatchLiveMatchView()
        }
    }

    private func startMatch() {
        guard let partner = players.first(where: { $0.id == partnerID }),
              let firstServer = players.first(where: { $0.id == firstServerID }) else { return }
        let opponents = players.dropFirst().filter { $0.id != partnerID }
        guard opponents.count == 2 else { return }

        var state = MatchState(
            teamA: Team(players: [players[0], partner]),
            teamB: Team(players: Array(opponents)),
            settings: MatchSettings(goldenPoint: false, setsToWin: 1)
        )
        state.setCurrentServer(playerID: firstServer.id)
        store.activeMatch = state
        connectivity.send(.match(state))
        WKInterfaceDevice.current().play(.start)
        matchStarted = true
    }
}

#Preview {
    NavigationStack { WatchNewMatchView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
