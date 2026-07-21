import SwiftUI
import PadelKit

struct WatchNewAmericanoView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var selectedPlayerIDs: Set<UUID> = []
    @State private var pointsPerRound = 21
    @State private var format: AmericanoFormat = .americano
    @State private var fixedPartners = false
    @State private var navigate = false
    private var roster: [Player] { connectivity.playerRoster.players }
    private var selectedPlayers: [Player] { roster.filter { selectedPlayerIDs.contains($0.id) } }
    private var playerCount: Int { selectedPlayers.count }

    /// One court per four players — the same rule the phone uses. Shown so the
    /// setup reads as a plain summary instead of yet another dial to fiddle with.
    private var courtCount: Int { max(1, playerCount / 4) }

    var body: some View {
        Form {
            // Format first, as a plain segmented choice: the old toggle buried
            // "Mexicano" behind a parenthetical nobody reads on a tiny screen.
            Section {
                Picker("Format", selection: $format) {
                    ForEach(AmericanoFormat.allCases, id: \.self) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .font(.footnote)
                .pickerStyle(.navigationLink)
            }

            // Only the two knobs that actually change how it plays. Rounds and
            // courts are derived so setup is "pick players, pick points, start".
            Section {
                Stepper(value: $pointsPerRound, in: 8...40, step: 1) {
                    Text("Points/round: \(pointsPerRound)").font(.footnote)
                }
                Toggle(isOn: $fixedPartners) {
                    Text("Fixed partners").font(.footnote)
                }
            } footer: {
                Text(summary).font(.caption2)
            }

            Section {
                NavigationLink {
                    WatchMixPlayersView(players: roster, selection: $selectedPlayerIDs)
                } label: {
                    HStack {
                        Text("Players").font(.footnote)
                        Spacer()
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
        selectedPlayerIDs = selectedPlayerIDs.intersection(Set(roster.map(\.id)))
        if selectedPlayerIDs.count < 4 {
            for player in roster where selectedPlayerIDs.count < 4 { selectedPlayerIDs.insert(player.id) }
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

struct WatchMixPlayersView: View {
    let players: [Player]
    @Binding var selection: Set<UUID>

    var body: some View {
        List {
            ForEach(players) { player in
                Button {
                    if selection.contains(player.id) {
                        selection.remove(player.id)
                    } else if selection.count < 16 {
                        selection.insert(player.id)
                    }
                } label: {
                    HStack {
                        Text(player.initials)
                            .font(.headline.monospaced())
                            .frame(width: 34)
                        Text(player.name).font(.caption2).lineLimit(1)
                        Spacer()
                        if selection.contains(player.id) { Image(systemName: "checkmark") }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { WatchNewAmericanoView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
