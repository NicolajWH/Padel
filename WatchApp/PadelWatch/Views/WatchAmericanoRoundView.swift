import SwiftUI
import WatchKit
import PadelKit

struct WatchAmericanoRoundView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var roundIndex: Int = 0
    @State private var didInitializeRound = false

    private var session: AmericanoSession? { store.activeAmericano }

    var body: some View {
        if let session {
            let round = session.rounds.indices.contains(roundIndex) ? session.rounds[roundIndex] : nil

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Round \(roundIndex + 1) / \(session.rounds.count)")
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
                if !didInitializeRound {
                    roundIndex = session.currentRoundIndex
                    didInitializeRound = true
                }
            }
            .onChange(of: connectivity.lastReceivedAmericano) { _, incoming in
                guard let incoming, incoming.id == session.id, incoming != session else { return }
                store.activeAmericano = incoming
                // Someone else (phone or another player) updated the score.
                WKInterfaceDevice.current().play(.notification)
            }
        } else {
            ContentUnavailableView("No Active Americano", systemImage: "person.3")
        }
    }

    private func apply(_ updated: AmericanoSession) {
        store.activeAmericano = updated
        connectivity.send(.americano(updated))
        if updated.isComplete {
            connectivity.send(.americanoFinished(updated))
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
        VStack(spacing: 6) {
            Text("Court \(matchup.court)").font(.caption2).foregroundStyle(.secondary)

            Button {
                addPoint(.teamA)
            } label: {
                scoreRow(name: matchup.teamA.displayName, points: score.a, color: PadelTheme.teamA)
            }
            .buttonStyle(.plain)
            .disabled(score.isComplete)

            Button {
                addPoint(.teamB)
            } label: {
                scoreRow(name: matchup.teamB.displayName, points: score.b, color: PadelTheme.teamB)
            }
            .buttonStyle(.plain)
            .disabled(score.isComplete)

            HStack {
                if score.isComplete {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption2)
                }
                Spacer()
                Button {
                    undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .font(.caption2)
                .disabled(matchup.pointLog.isEmpty)
            }
        }
        .padding(.horizontal, 6)
    }

    private func scoreRow(name: String, points: Int, color: Color) -> some View {
        HStack {
            Text(name).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.6)
            Spacer()
            Text("\(points)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
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
