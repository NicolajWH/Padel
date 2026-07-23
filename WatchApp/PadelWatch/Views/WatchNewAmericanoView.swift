import SwiftUI
import PadelKit

struct WatchNewAmericanoView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var selectedPlayerIDs: [UUID] = []
    @State private var pointsPerRound = 21
    @State private var format: AmericanoFormat = .americano
    @State private var fixedPartners = false
    @State private var navigate = false
    private var roster: [Player] { connectivity.playerRoster.players }
    private var selectedPlayers: [Player] {
        selectedPlayerIDs.compactMap { id in roster.first { $0.id == id } }
    }
    private var playerCount: Int { selectedPlayers.count }

    /// One court per four players — the same rule the phone uses. Shown so the
    /// setup reads as a plain summary instead of yet another dial to fiddle with.
    private var courtCount: Int { max(1, playerCount / 4) }

    var body: some View {
        Form {
            Section("Players") {
                NavigationLink {
                    WatchPlayerSelectionView(
                        players: roster,
                        selection: $selectedPlayerIDs,
                        maximumSelection: 16
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose players").font(.footnote)
                        Text(selectedPlayers.prefix(4).map(\.initials).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if roster.count < 4 {
                    Text("Create at least 4 players in the iPhone app")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Format", selection: $format) {
                    ForEach(AmericanoFormat.allCases, id: \.self) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .font(.footnote)
                .pickerStyle(.navigationLink)
                Stepper(value: $pointsPerRound, in: 8...40, step: 1) {
                    Text("Points/round: \(pointsPerRound)").font(.footnote)
                }
                Toggle(isOn: $fixedPartners) {
                    Text("Fixed partners").font(.footnote)
                }
            } header: {
                Text("Setup")
            } footer: {
                Text(summary).font(.caption2)
            }

            Section {
                Button {
                    start()
                } label: {
                    Text("Start")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(PadelTheme.lime)
                .disabled(playerCount < 4)
            }
        }
        .navigationTitle("Mix")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: selectDefaults)
        .onChange(of: roster) { _, _ in selectDefaults() }
        .navigationDestination(isPresented: $navigate) {
            WatchAmericanoRoundView()
        }
    }

    private var summary: String {
        let rounds = AmericanoSettings.standard(playerCount: playerCount).numberOfRounds
        let courtsText = courtCount == 1
            ? String(localized: "1 court")
            : String(localized: "\(courtCount) courts")
        let roundsText = String(localized: "\(rounds) rounds")
        return "\(courtsText) · \(roundsText)"
    }

    private func selectDefaults() {
        var seen = Set<UUID>()
        selectedPlayerIDs = selectedPlayerIDs.filter { id in
            roster.contains { $0.id == id } && seen.insert(id).inserted
        }
        if selectedPlayerIDs.count < 4 {
            for player in roster where selectedPlayerIDs.count < 4 && !selectedPlayerIDs.contains(player.id) {
                selectedPlayerIDs.append(player.id)
            }
        }
    }

    private func start() {
        let players = selectedPlayers
        // Derive rounds/courts from the shared default so the watch matches the
        // phone; only the two hand-picked values (points, format) override it.
        var settings = AmericanoSettings.standard(playerCount: playerCount)
        settings.pointsPerRound = pointsPerRound
        settings.format = format
        settings.fixedPartners = fixedPartners
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        let session = AmericanoSession(name: format.displayName, players: players, settings: settings, rounds: rounds)
        store.activeAmericano = session
        connectivity.send(.americano(session))
        navigate = true
    }
}

#Preview {
    NavigationStack { WatchNewAmericanoView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
