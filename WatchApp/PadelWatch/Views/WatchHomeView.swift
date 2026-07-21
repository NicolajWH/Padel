import SwiftUI
import PadelKit

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @ObservedObject private var workout = WorkoutManager.shared
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
                                Text("Continue Mix").font(.headline)
                                Text(session.name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listItemTint(PadelTheme.courtDeep)
                }
            }

            Section {
                NavigationLink {
                    WatchNewMatchView()
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
                        Text("New Mix")
                    } icon: {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(PadelTheme.teamB)
                    }
                }
            }

            // Safety valve: a workout keeps running when a match is abandoned
            // mid-set, so make it visible and endable from the home screen.
            if workout.isRunning {
                Section {
                    Button {
                        workout.end()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading) {
                                Text("End Workout").font(.headline)
                                Text(workoutSummary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
        // When the iPhone starts a match, open the scoreboard here automatically
        // so the watch is ready to score — no need to fumble with the tiny screen.
        .onChange(of: store.matchToPresent?.id) { _, id in
            guard id != nil else { return }
            presentIncomingMatch()
        }
        .task {
            // A match may have landed (e.g. via application context at launch)
            // before this view began observing — catch it on appear too.
            presentIncomingMatch()
        }
    }

    private func presentIncomingMatch() {
        guard store.matchToPresent != nil else { return }
        store.matchToPresent = nil
        quickMatchStarted = true
    }

    private var workoutSummary: String {
        var parts: [String] = []
        if workout.heartRate > 0 { parts.append("\(Int(workout.heartRate)) bpm") }
        if workout.activeCalories > 0 { parts.append("\(Int(workout.activeCalories)) kcal") }
        return parts.isEmpty ? String(localized: "Recording to Health") : parts.joined(separator: " · ")
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
