import SwiftUI
import WatchKit
import PadelKit

struct WatchNewMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var selectedPlayerIDs = Set<UUID>()
    @State private var partnerID: UUID?
    @State private var firstServerID: UUID?
    @State private var matchStarted = false

    private let columns = [GridItem(.adaptive(minimum: 42), spacing: 6)]
    private var owner: Player? { store.playerRoster?.owner }
    private var candidates: [Player] {
        guard let owner else { return [] }
        return (store.playerRoster?.allPlayers ?? []).filter { $0.id != owner.id }
    }
    private var selectedPlayers: [Player] {
        candidates.filter { selectedPlayerIDs.contains($0.id) }
    }

    var body: some View {
        Form {
            if let owner {
                Section("You") {
                    PlayerInitialsChip(player: owner, isSelected: true) {}
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(candidates) { player in
                            PlayerInitialsChip(
                                player: player,
                                isSelected: selectedPlayerIDs.contains(player.id)
                            ) { toggle(player) }
                            .disabled(selectedPlayerIDs.count == 3 && !selectedPlayerIDs.contains(player.id))
                        }
                    }
                } header: {
                    Text("Choose 3 Players")
                } footer: {
                    Text("Selected: \(selectedPlayerIDs.count) of 3")
                }

                if selectedPlayers.count == 3 {
                    Section("My Partner") {
                        chipGrid(players: selectedPlayers, selection: $partnerID)
                    }
                    Section("First Server") {
                        chipGrid(players: [owner] + selectedPlayers, selection: $firstServerID)
                    }
                    Button("Start Match") { startMatch(owner: owner) }
                        .disabled(partnerID == nil || firstServerID == nil)
                }
            } else {
                ContentUnavailableView(
                    "No Player Profile",
                    systemImage: "iphone",
                    description: Text("Add your name and players in Settings on iPhone, then open this screen again.")
                )
            }
        }
        .navigationTitle("New Match")
        .navigationDestination(isPresented: $matchStarted) { WatchLiveMatchView() }
        .task { connectivity.send(.requestLatest) }
    }

    private func chipGrid(players: [Player], selection: Binding<UUID?>) -> some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(players) { player in
                PlayerInitialsChip(player: player, isSelected: selection.wrappedValue == player.id) {
                    selection.wrappedValue = player.id
                }
            }
        }
    }

    private func toggle(_ player: Player) {
        if selectedPlayerIDs.remove(player.id) == nil { selectedPlayerIDs.insert(player.id) }
        if !selectedPlayerIDs.contains(partnerID ?? UUID()) { partnerID = nil }
        if firstServerID != owner?.id, !selectedPlayerIDs.contains(firstServerID ?? UUID()) { firstServerID = nil }
    }

    private func startMatch(owner: Player) {
        guard let partner = selectedPlayers.first(where: { $0.id == partnerID }),
              let firstServerID else { return }
        let opponents = selectedPlayers.filter { $0.id != partner.id }
        guard opponents.count == 2 else { return }
        var state = MatchState(
            teamA: Team(players: [owner, partner]),
            teamB: Team(players: opponents),
            settings: MatchSettings(goldenPoint: false, setsToWin: 1)
        )
        state.setCurrentServer(playerID: firstServerID)
        store.activeMatch = state
        connectivity.send(.match(state))
        WKInterfaceDevice.current().play(.start)
        matchStarted = true
    }
}

private struct PlayerInitialsChip: View {
    let player: Player
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(player.initials)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(isSelected ? PadelTheme.lime : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(isSelected ? .black : .white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { WatchNewMatchView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
