import SwiftUI
import PadelKit

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var quickMatchStarted = false

    var body: some View {
        List {
            if let match = store.activeMatch, !match.isFinished {
                Section {
                    NavigationLink {
                        WatchLiveMatchView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(PadelTheme.lime)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("Continue Match").font(.headline)
                                Text(scoreSummary(for: match))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listItemTint(PadelTheme.courtDeep)
                }
            }

            if let session = store.activeAmericano, !session.isComplete, !session.rounds.isEmpty {
                Section {
                    NavigationLink {
                        WatchAmericanoRoundView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(PadelTheme.lime)
                                .font(.caption)
                            VStack(alignment: .leading) {
                                Text("Continue Americano").font(.headline)
                                Text(session.name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listItemTint(PadelTheme.courtDeep)
                }
            }

            Section {
                Button {
                    startQuickMatch()
                } label: {
                    Label {
                        Text("New Match")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(PadelTheme.teamA)
                    }
                }
                NavigationLink {
                    WatchNewAmericanoView()
                } label: {
                    Label {
                        Text("New Americano")
                    } icon: {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(PadelTheme.teamB)
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: connectivity.isPhoneReachable ? "iphone.gen3" : "iphone.slash")
                    if connectivity.isPhoneReachable {
                        Text("iPhone Connected")
                    } else {
                        Text("iPhone Offline")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Padel")
        .navigationDestination(isPresented: $quickMatchStarted) {
            WatchLiveMatchView()
        }
    }

    /// Starts scoring immediately with the standard casual ruleset — no setup
    /// questions on the tiny screen. Advanced rule tweaks live on the iPhone.
    private func startQuickMatch() {
        let teamA = Team(players: [Player(name: "Team A-1"), Player(name: "Team A-2")])
        let teamB = Team(players: [Player(name: "Team B-1"), Player(name: "Team B-2")])
        let settings = MatchSettings(goldenPoint: false, setsToWin: 1)
        let state = MatchState(teamA: teamA, teamB: teamB, settings: settings)
        store.activeMatch = state
        connectivity.send(.match(state))
        quickMatchStarted = true
    }

    private func scoreSummary(for match: MatchState) -> String {
        let snap = match.snapshot
        let points = snap.isTiebreak
            ? "\(snap.tiebreakPointsA)–\(snap.tiebreakPointsB)"
            : "\(snap.gamePointLabelA)–\(snap.gamePointLabelB)"
        return "\(snap.currentSetGamesA)–\(snap.currentSetGamesB) · \(points)"
    }
}

#Preview {
    NavigationStack { WatchHomeView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
