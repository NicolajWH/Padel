import SwiftUI
import WatchKit
import PadelKit

struct WatchLiveMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var crownValue: Double = 0.5
    @State private var showingFinished = false

    private var state: MatchState? { store.activeMatch }

    var body: some View {
        if let state {
            let snap = state.snapshot
            VStack(spacing: 4) {
                if !snap.completedSets.isEmpty {
                    Text(snap.completedSets.map { "\($0.teamAGames)-\($0.teamBGames)" }.joined(separator: "  "))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                TeamTapZone(
                    name: state.teamA.displayName,
                    label: snap.isTiebreak ? "\(snap.tiebreakPointsA)" : snap.gamePointLabelA,
                    games: snap.currentSetGamesA,
                    isServing: snap.servingSide == .teamA,
                    color: .blue
                ) {
                    score(.teamA)
                }

                TeamTapZone(
                    name: state.teamB.displayName,
                    label: snap.isTiebreak ? "\(snap.tiebreakPointsB)" : snap.gamePointLabelB,
                    games: snap.currentSetGamesB,
                    isServing: snap.servingSide == .teamB,
                    color: .red
                ) {
                    score(.teamB)
                }

                Button {
                    undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(state.pointLog.isEmpty)
            }
            .focusable(true)
            .digitalCrownRotation($crownValue, from: 0, through: 1, by: 0.001, sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { _, newValue in
                if newValue < 0.35 || newValue > 0.65 {
                    undo()
                    crownValue = 0.5
                }
            }
            .navigationTitle(snap.isMatchTiebreak ? "Match TB" : (snap.isTiebreak ? "Tiebreak" : "Live"))
            .onChange(of: snap.isMatchOver) { _, isOver in
                if isOver {
                    WKInterfaceDevice.current().play(.success)
                    store.archiveMatchIfFinished()
                    connectivity.send(.matchFinished(state))
                    showingFinished = true
                }
            }
            .onChange(of: connectivity.lastReceivedMatch) { _, incoming in
                guard let incoming, incoming.id == state.id, incoming.pointLog.count > state.pointLog.count else { return }
                store.activeMatch = incoming
            }
            .sheet(isPresented: $showingFinished) {
                WatchMatchResultView(state: state)
            }
        } else {
            ContentUnavailableView("No Active Match", systemImage: "tennis.racket")
        }
    }

    private func score(_ side: TeamSide) {
        guard var state = state, !state.snapshot.isMatchOver else { return }
        state.addPoint(for: side)
        store.activeMatch = state
        WKInterfaceDevice.current().play(.click)
        connectivity.send(.match(state))
    }

    private func undo() {
        guard var state = state else { return }
        state.undoLastPoint()
        store.activeMatch = state
        WKInterfaceDevice.current().play(.directionUp)
        connectivity.send(.match(state))
    }
}

private struct TeamTapZone: View {
    let name: String
    let label: String
    let games: Int
    let isServing: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if isServing {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(color)
                        }
                        Text(name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text("Games \(games)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(label)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let store = WatchStore.shared
    store.activeMatch = MatchState(
        teamA: Team(players: [Player(name: "Alice"), Player(name: "Ana")]),
        teamB: Team(players: [Player(name: "Bea"), Player(name: "Bob")])
    )
    return NavigationStack { WatchLiveMatchView() }
        .environmentObject(store)
        .environmentObject(WatchConnectivityManager.shared)
}
