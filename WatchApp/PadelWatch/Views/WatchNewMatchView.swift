import SwiftUI
import WatchKit
import PadelKit

struct WatchNewMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    @State private var selectedIDs: [UUID] = []
    @State private var firstServerID: UUID?
    @State private var goldenPoint = false
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
                    NavigationLink {
                        WatchPlayerSelectionView(
                            players: roster,
                            selection: $selectedIDs,
                            maximumSelection: 4
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Choose players")
                                .font(.footnote)
                            Text(selectedPlayers.map(\.initials).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Section("Setup") {
                Picker("First Server", selection: $firstServerID) {
                    ForEach(selectedPlayers) { player in
                        Text(player.initials).tag(player.id as UUID?)
                    }
                }
                Toggle("Golden Point", isOn: $goldenPoint)
            }

            Button("Start Match") { startMatch() }
                .disabled(Set(selectedIDs).count != 4 || firstServerID == nil)
                .tint(PadelTheme.lime)
        }
        .navigationTitle("New Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $matchStarted) {
            WatchLiveMatchView()
        }
        .onAppear(perform: selectDefaults)
        .onChange(of: roster) { _, _ in selectDefaults() }
        .onChange(of: selectedIDs) { _, ids in
            if !ids.contains(firstServerID ?? UUID()) { firstServerID = ids.first }
        }
    }

    private func selectDefaults() {
        var seen = Set<UUID>()
        let valid = selectedIDs.filter { id in
            roster.contains { $0.id == id } && seen.insert(id).inserted
        }
        selectedIDs = Array((valid + roster.map(\.id).filter { !valid.contains($0) }).prefix(4))
        if !selectedIDs.contains(firstServerID ?? UUID()) { firstServerID = selectedIDs.first }
    }

    private func startMatch() {
        guard selectedPlayers.count == 4, let firstServerID else { return }

        var state = MatchState(
            teamA: Team(players: Array(selectedPlayers.prefix(2))),
            teamB: Team(players: Array(selectedPlayers.suffix(2))),
            settings: MatchSettings(goldenPoint: goldenPoint, setsToWin: 1)
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
