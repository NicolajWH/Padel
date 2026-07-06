import SwiftUI
import WatchKit
import PadelKit

struct WatchLiveMatchView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @ObservedObject private var workout = WorkoutManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var crownValue: Double = 0.5
    @State private var lastUndoAt: Date = .distantPast
    @State private var showingFinished = false

    private var state: MatchState? { store.activeMatch }

    var body: some View {
        if let state {
            let snap = state.snapshot
            let showSets = state.settings.setsToWin > 1
            VStack(spacing: 4) {
                // Fixed orientation: opponents always on top, your team always at
                // the bottom — like standing on your own side of the court. The
                // serving side is marked with the lime ball instead of reordering
                // the zones, so the tap targets never move mid-match.
                TeamTapZone(
                    points: snap.isTiebreak ? "\(snap.tiebreakPointsB)" : snap.gamePointLabelB,
                    games: snap.currentSetGamesB,
                    sets: showSets ? snap.setsWonB : nil,
                    isServing: snap.servingSide == .teamB,
                    color: PadelTheme.teamB
                ) {
                    score(.teamB)
                }

                HStack(spacing: 4) {
                    CalledScoreBadge(snap: snap)
                    if workout.isRunning, workout.heartRate > 0 {
                        HeartRateBadge(bpm: workout.heartRate)
                    }
                    if !connectivity.isPhoneReachable {
                        WatchOfflineBadge()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: connectivity.isPhoneReachable)

                TeamTapZone(
                    points: snap.isTiebreak ? "\(snap.tiebreakPointsA)" : snap.gamePointLabelA,
                    games: snap.currentSetGamesA,
                    sets: showSets ? snap.setsWonA : nil,
                    isServing: snap.servingSide == .teamA,
                    color: PadelTheme.teamA
                ) {
                    score(.teamA)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .gesture(backSwipe)
            .focusable(true)
            .digitalCrownRotation($crownValue, from: 0, through: 1, by: 0.001, sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { _, newValue in
                // Undo one point per crown "step". A fast spin used to fire many
                // undos before the value snapped back to centre, wiping a whole
                // set (or the match) at once. Re-centre immediately and enforce a
                // short cooldown so points back out one at a time, steadily.
                guard newValue < 0.35 || newValue > 0.65 else { return }
                crownValue = 0.5
                let now = Date()
                guard now.timeIntervalSince(lastUndoAt) > 0.3 else { return }
                lastUndoAt = now
                undo()
            }
            .onAppear {
                workout.startIfNeeded()
            }
            .onChange(of: snap.isMatchOver) { _, isOver in
                if isOver {
                    WKInterfaceDevice.current().play(.success)
                    store.archiveMatchIfFinished()
                    connectivity.send(.matchFinished(state))
                    workout.end()
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
                WatchMatchResultView(
                    state: state,
                    onClose: {
                        // Close the finished match and return to the start menu.
                        showingFinished = false
                        store.activeMatch = nil
                        dismiss()
                    },
                    onRematch: {
                        // Start a fresh match with the same teams and rules.
                        showingFinished = false
                        let rematch = MatchState(
                            teamA: state.teamA,
                            teamB: state.teamB,
                            settings: state.settings
                        )
                        store.activeMatch = rematch
                        connectivity.send(.match(rematch))
                        crownValue = 0.5
                        workout.startIfNeeded()
                    }
                )
            }
        } else {
            ContentUnavailableView("No Active Match", systemImage: "tennis.racket")
        }
    }

    /// The navigation bar is hidden for a full-screen scoreboard, so leaving the
    /// match is done by swiping right-to-left anywhere on the screen instead.
    private var backSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.width < -50, abs(value.translation.height) < abs(value.translation.width) {
                    dismiss()
                }
            }
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
    let points: String
    let games: Int
    let sets: Int?
    let isServing: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PadelTheme.lime)
                    .opacity(isServing ? 1 : 0)

                Text(points)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    if let sets {
                        ScoreColumn(value: sets, caption: "Sets")
                    }
                    ScoreColumn(value: games, caption: "Games")
                }
            }
            .padding(.horizontal, 10)
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
                            .strokeBorder(color.opacity(isServing ? 0.8 : 0.25), lineWidth: isServing ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// The score as you'd call it on court: the serving team's points always come
/// first ("15-0" when the server leads, "0-15" when the receiver does). The tap
/// zones stay fixed top/bottom, so this badge is where the convention lives.
private struct CalledScoreBadge: View {
    let snap: MatchSnapshot

    private var serverFirstScore: String {
        let a = snap.isTiebreak ? "\(snap.tiebreakPointsA)" : snap.gamePointLabelA
        let b = snap.isTiebreak ? "\(snap.tiebreakPointsB)" : snap.gamePointLabelB
        return snap.servingSide == .teamA ? "\(a)–\(b)" : "\(b)–\(a)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tennisball.fill")
                .font(.system(size: 8))
                .foregroundStyle(snap.isTiebreak ? .black : PadelTheme.lime)
            Text(serverFirstScore)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            if snap.isTiebreak {
                Text(snap.isMatchTiebreak ? "Match TB" : "TB")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(snap.isTiebreak ? .black : .white)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Capsule().fill(snap.isTiebreak ? PadelTheme.lime : Color.white.opacity(0.1)))
    }
}

/// Live heart rate from the running workout session.
private struct HeartRateBadge: View {
    let bpm: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
            Text("\(Int(bpm))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

/// A small labelled number so games (and sets) can't be mistaken for points.
private struct ScoreColumn: View {
    let value: Int
    let caption: LocalizedStringKey

    var body: some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption)
                .font(.system(size: 8, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
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
