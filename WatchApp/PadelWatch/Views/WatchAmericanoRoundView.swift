import SwiftUI
import WatchKit
import PadelKit

struct WatchAmericanoRoundView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @ObservedObject private var workout = WorkoutManager.shared
    @State private var roundIndex: Int = 0
    @State private var didInitializeRound = false

    private var session: AmericanoSession? { store.activeAmericano }

    var body: some View {
        if let session {
            let round = session.rounds.indices.contains(roundIndex) ? session.rounds[roundIndex] : nil

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Round \(roundIndex + 1) / \(session.plannedRoundCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !connectivity.isPhoneReachable {
                        WatchOfflineBadge()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: connectivity.isPhoneReachable)

                if let round {
                    TabView {
                        ForEach(round.matchups) { matchup in
                            MatchupScoringView(session: session, roundIndex: roundIndex, matchup: matchup) { updated in
                                apply(updated)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                }

                HStack {
                    Button {
                        roundIndex = max(0, roundIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(roundIndex == 0)

                    NavigationLink("Standings") {
                        WatchAmericanoStandingsView(session: session)
                    }
                    .font(.caption2)

                    Button {
                        roundIndex = min(session.rounds.count - 1, roundIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(roundIndex >= session.rounds.count - 1)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(session.name)
            .onAppear {
                workout.startIfNeeded()
                if !didInitializeRound {
                    roundIndex = session.currentRoundIndex
                    didInitializeRound = true
                }
            }
            .onChange(of: connectivity.lastReceivedAmericano) { _, incoming in
                guard let incoming, incoming.id == session.id, incoming != session else { return }
                // Growing the session here too is safe: Mexicano round
                // generation is deterministic, so the watch and the phone
                // derive the exact same next round.
                var grown = incoming
                grown.appendNextRoundIfNeeded()
                store.activeAmericano = grown
                if grown.isComplete {
                    WorkoutManager.shared.end()
                }
                // Someone else (phone or another player) updated the score.
                WKInterfaceDevice.current().play(.notification)
            }
        } else {
            ContentUnavailableView("No Active Americano", systemImage: "person.3")
        }
    }

    private func apply(_ updated: AmericanoSession) {
        var updated = updated
        if updated.appendNextRoundIfNeeded() {
            roundIndex = updated.currentRoundIndex
        }
        store.activeAmericano = updated
        connectivity.send(.americano(updated))
        if updated.isComplete {
            connectivity.send(.americanoFinished(updated))
            WorkoutManager.shared.end()
        }
    }
}

private struct MatchupScoringView: View {
    let session: AmericanoSession
    let roundIndex: Int
    let matchup: AmericanoMatchup
    let onUpdate: (AmericanoSession) -> Void

    var body: some View {
        let score = matchup.score(target: session.settings.pointsPerRound)
        // Mirror the regular match layout: two full-height gradient zones with a
        // big rounded number that auto-scales, so Americano feels like the same
        // scoreboard. A compact header carries the court, target and undo that
        // the point structure here (a straight race, no games/sets) needs.
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("Court \(matchup.court)")
                    .font(.system(size: 11, weight: .semibold))
                Text("to \(session.settings.pointsPerRound)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if score.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
                Spacer()
                Button {
                    undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(matchup.pointLog.isEmpty)
            }
            .padding(.horizontal, 6)

            AmericanoTeamZone(
                name: matchup.teamA.displayName,
                points: score.a,
                color: PadelTheme.teamA,
                isWinner: score.isComplete && score.a > score.b
            ) {
                addPoint(.teamA)
            }
            .disabled(score.isComplete)

            AmericanoTeamZone(
                name: matchup.teamB.displayName,
                points: score.b,
                color: PadelTheme.teamB,
                isWinner: score.isComplete && score.b > score.a
            ) {
                addPoint(.teamB)
            }
            .disabled(score.isComplete)
        }
        .padding(.horizontal, 4)
    }

    private func addPoint(_ side: TeamSide) {
        var session = session
        guard var round = session.rounds[safe: roundIndex] else { return }
        guard let idx = round.matchups.firstIndex(where: { $0.id == matchup.id }) else { return }
        round.matchups[idx].addPoint(to: side, target: session.settings.pointsPerRound)
        session.rounds[roundIndex] = round
        WKInterfaceDevice.current().play(.click)
        onUpdate(session)
    }

    private func undo() {
        var session = session
        guard var round = session.rounds[safe: roundIndex] else { return }
        guard let idx = round.matchups.firstIndex(where: { $0.id == matchup.id }) else { return }
        round.matchups[idx].undoLastPoint()
        session.rounds[roundIndex] = round
        onUpdate(session)
    }
}

/// A full-height team zone matching the regular match's `TeamTapZone`: a gradient
/// card with the team name and a big rounded number that scales down to fit. The
/// winner is highlighted with a brighter border, echoing how the live match marks
/// the serving side.
private struct AmericanoTeamZone: View {
    let name: String
    let points: Int
    let color: Color
    let isWinner: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(points)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.32), color.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(color.opacity(isWinner ? 0.8 : 0.25), lineWidth: isWinner ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let players = (1...4).map { Player(name: "P\($0)") }
    let settings = AmericanoSettings.standard(playerCount: 4)
    let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
    let store = WatchStore.shared
    store.activeAmericano = AmericanoSession(players: players, settings: settings, rounds: rounds)
    return NavigationStack { WatchAmericanoRoundView() }
        .environmentObject(store)
        .environmentObject(WatchConnectivityManager.shared)
}
