import SwiftUI
import WatchKit
import PadelKit

struct WatchNewMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    @State private var selectedIDs: [UUID] = []
    @State private var firstServerID: UUID?
    @State private var matchStarted = false

    private var roster: [Player] { connectivity.playerRoster.players }
    private var selectedPlayers: [Player] {
        selectedIDs.compactMap { id in roster.first { $0.id == id } }
    }

    var body: some View {
        Form {
            Section("Players") {
                if roster.count < 4 {
                    Text("Create at least 4 players in the iPhone app")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(0..<4, id: \.self) { index in
                        Picker("Player \(index + 1)", selection: selection(for: index)) {
                            ForEach(roster) { player in
                                Text(player.initials).tag(player.id as UUID?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
            }

            Section("Setup") {
                Picker("First Server", selection: $firstServerID) {
                    ForEach(selectedPlayers) { player in
                        Text(player.initials).tag(player.id as UUID?)
                    }
                }
            }

            Button("Start Match") { startMatch() }
                .disabled(Set(selectedIDs).count != 4 || firstServerID == nil)
        }
        .navigationTitle("New Match")
        .navigationDestination(isPresented: $matchStarted) {
            WatchLiveMatchView()
        }
        .onAppear(perform: selectDefaults)
        .onChange(of: roster) { _, _ in selectDefaults() }
    }

    private func selection(for index: Int) -> Binding<UUID?> {
        Binding(
            get: { selectedIDs.indices.contains(index) ? selectedIDs[index] : nil },
            set: { newID in
                guard let newID else { return }
                while selectedIDs.count <= index { selectedIDs.append(newID) }
                selectedIDs[index] = newID
                if index == 0 { firstServerID = newID }
            }
        )
    }

    private func selectDefaults() {
        let valid = selectedIDs.filter { id in roster.contains { $0.id == id } }
        selectedIDs = Array((valid + roster.map(\.id).filter { !valid.contains($0) }).prefix(4))
        if !selectedIDs.contains(firstServerID ?? UUID()) { firstServerID = selectedIDs.first }
    }

    private func startMatch() {
        guard selectedPlayers.count == 4, let firstServerID else { return }

        var state = MatchState(
            teamA: Team(players: Array(selectedPlayers.prefix(2))),
            teamB: Team(players: Array(selectedPlayers.suffix(2))),
            settings: MatchSettings(goldenPoint: false, setsToWin: 1)
        )
        state.setCurrentServer(playerID: firstServerID)
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
