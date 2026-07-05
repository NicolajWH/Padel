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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PadelTheme.lime)
                }

                TeamTapZone(
                    name: state.teamA.displayName,
                    label: snap.isTiebreak ? "\(snap.tiebreakPointsA)" : snap.gamePointLabelA,
                    games: snap.currentSetGamesA,
                    isServing: snap.servingSide == .teamA,
                    color: PadelTheme.teamA
                ) {
                    score(.teamA)
                }

                TeamTapZone(
                    name: state.teamB.displayName,
                    label: snap.isTiebreak ? "\(snap.tiebreakPointsB)" : snap.gamePointLabelB,
                    games: snap.currentSetGamesB,
                    isServing: snap.servingSide == .teamB,
                    color: PadelTheme.teamB
                ) {
                    score(.teamB)
                }

                Button {
                    undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(PadelTheme.lime)
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
            .navigationTitle(title(for: snap))
            .onChange(of: snap.isMatchOver) { _, isOver in
                if isOver {
                    WKInterfaceDevice.current().play(.success)
                    store.archiveMatchIfFinished()
                    connectivity.send(.matchFinished(state))
                    showingFinished = true
                }
            }
            .onChange(of: connectivity.lastReceivedMatch) { _, incoming in
                guard let incoming, incoming.id == state.id, incoming != state else { return }
                withAnimation(.snappy) { store.activeMatch = incoming }
                // Someone else (phone or another player) updated the score.
                WKInterfaceDevice.current().play(.notification)
            }
            .sheet(isPresented: $showingFinished) {
                WatchMatchResultView(state: state)
            }
        } else {
            ContentUnavailableView("No Active Match", systemImage: "tennis.racket")
        }
    }

    private func title(for snap: MatchSnapshot) -> String {
        if snap.isMatchTiebreak { return String(localized: "Match TB") }
        if snap.isTiebreak { return String(localized: "Tiebreak") }
        return String(localized: "Live")
    }

    private func score(_ side: TeamSide) {
        guard var state = state, !state.snapshot.isMatchOver else { return }
        withAnimation(.snappy) {
            state.addPoint(for: side)
            store.activeMatch = state
        }
        WKInterfaceDevice.current().play(.click)
        connectivity.send(.match(state))
    }

    private func undo() {
        guard var state = state else { return }
        withAnimation(.snappy) {
            state.undoLastPoint()
            store.activeMatch = state
        }
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
                            Image(systemName: "tennisball.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(PadelTheme.lime)
                        }
                        Text(name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text("Games \(games)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(label)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
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
                            .strokeBorder(color.opacity(isServing ? 0.8 : 0.25), lineWidth: isServing ? 1.5 : 1)
                    )
            )
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
