import SwiftUI
import PadelKit

struct WatchNewAmericanoView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var playerCount = 4
    @State private var pointsPerRound = 21
    @State private var numberOfRounds = 3
    @State private var isMexicano = false
    @State private var navigate = false

    var body: some View {
        Form {
            Stepper("Players: \(playerCount)", value: $playerCount, in: 4...16, step: 4)
            Stepper("Points/round: \(pointsPerRound)", value: $pointsPerRound, in: 8...40, step: 1)
            Stepper("Rounds: \(numberOfRounds)", value: $numberOfRounds, in: 1...10)
            Toggle("Mexicano (seed by standings)", isOn: $isMexicano)

            Button("Generate & Start") { start() }
        }
        .navigationTitle("Americano")
        .navigationDestination(isPresented: $navigate) {
            WatchAmericanoRoundView()
        }
    }

    private func start() {
        let format: AmericanoFormat = isMexicano ? .mexicano : .americano
        let players = (1...playerCount).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: pointsPerRound, numberOfCourts: max(1, playerCount / 4), numberOfRounds: numberOfRounds, format: format)
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
