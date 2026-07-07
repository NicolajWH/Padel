import SwiftUI
import PadelKit

struct WatchNewAmericanoView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var playerCount = 4
    @State private var pointsPerRound = 21
    @State private var format: AmericanoFormat = .americano
    @State private var navigate = false

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
                .pickerStyle(.navigationLink)
            }

            // Only the two knobs that actually change how it plays. Rounds and
            // courts are derived so setup is "pick players, pick points, start".
            Section {
                Stepper("Players: \(playerCount)", value: $playerCount, in: 4...16, step: 4)
                Stepper("Points/round: \(pointsPerRound)", value: $pointsPerRound, in: 8...40, step: 1)
            } footer: {
                Text(summary)
            }

            Section {
                Button {
                    start()
                } label: {
                    Text("Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(PadelTheme.lime)
            }
        }
        .navigationTitle(format.displayName)
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

    private func start() {
        let players = (1...playerCount).map { Player(name: "P\($0)") }
        // Derive rounds/courts from the shared default so the watch matches the
        // phone; only the two hand-picked values (points, format) override it.
        var settings = AmericanoSettings.standard(playerCount: playerCount)
        settings.pointsPerRound = pointsPerRound
        settings.format = format
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
