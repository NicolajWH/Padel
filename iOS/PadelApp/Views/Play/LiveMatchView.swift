import SwiftUI
import SwiftData
import PadelKit

struct LiveMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    let record: MatchRecord
    @State private var state: MatchState
    @State private var showingFinishedSheet = false

    init(record: MatchRecord, initialState: MatchState) {
        self.record = record
        self._state = State(initialValue: initialState)
    }

    var body: some View {
        let snap = state.snapshot

        VStack(spacing: 0) {
            SetHistoryBar(sets: snap.completedSets)
                .padding(.top, 8)

            HStack(spacing: 16) {
                TeamScoreColumn(
                    team: state.teamA,
                    label: snap.gamePointLabelA,
                    games: snap.currentSetGamesA,
                    isServing: snap.servingSide == .teamA,
                    servingPlayerIndex: snap.servingPlayerIndex,
                    isTiebreak: snap.isTiebreak,
                    tiebreakPoints: snap.tiebreakPointsA,
                    color: .blue
                ) {
                    score(.teamA)
                }

                TeamScoreColumn(
                    team: state.teamB,
                    label: snap.gamePointLabelB,
                    games: snap.currentSetGamesB,
                    isServing: snap.servingSide == .teamB,
                    servingPlayerIndex: snap.servingPlayerIndex,
                    isTiebreak: snap.isTiebreak,
                    tiebreakPoints: snap.tiebreakPointsB,
                    color: .red
                ) {
                    score(.teamB)
                }
            }
            .padding()

            HStack {
                Button {
                    undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(state.pointLog.isEmpty)

                Spacer()

                if connectivity.isWatchAppInstalled {
                    Label(connectivity.isWatchReachable ? "Watch Connected" : "Watch Not Reachable", systemImage: "applewatch")
                        .font(.caption)
                        .foregroundStyle(connectivity.isWatchReachable ? .green : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle(snap.isMatchTiebreak ? "Match Tiebreak" : (snap.isTiebreak ? "Tiebreak" : "Live Match"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: state.pointLog) { _, _ in
            persist()
        }
        .onAppear {
            connectivity.send(.match(state))
        }
        .onChange(of: connectivity.lastReceivedMatch) { _, incoming in
            guard let incoming, incoming.id == state.id else { return }
            if incoming.pointLog.count > state.pointLog.count {
                state = incoming
            }
        }
        .onChange(of: snap.isMatchOver) { _, isOver in
            if isOver {
                connectivity.send(.matchFinished(state))
                showingFinishedSheet = true
            }
        }
        .sheet(isPresented: $showingFinishedSheet) {
            MatchSummaryView(state: state)
        }
    }

    private func score(_ side: TeamSide) {
        guard !state.snapshot.isMatchOver else { return }
        state.addPoint(for: side)
        connectivity.send(.match(state))
    }

    private func undo() {
        state.undoLastPoint()
        connectivity.send(.match(state))
    }

    private func persist() {
        record.update(with: state)
    }
}

private struct TeamScoreColumn: View {
    let team: Team
    let label: String
    let games: Int
    let isServing: Bool
    let servingPlayerIndex: Int
    let isTiebreak: Bool
    let tiebreakPoints: Int
    let color: Color
    let onScore: () -> Void

    var body: some View {
        Button(action: onScore) {
            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    ForEach(Array(team.players.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 6) {
                            if isServing && index == servingPlayerIndex {
                                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(color)
                            }
                            Text(player.name)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                Text(isTiebreak ? "\(tiebreakPoints)" : label)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)

                Text("Games: \(games)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

private struct SetHistoryBar: View {
    let sets: [SetScore]

    var body: some View {
        if !sets.isEmpty {
            HStack(spacing: 12) {
                ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                    Text("\(set.teamAGames)-\(set.teamBGames)")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    let teamA = Team(players: [Player(name: "Alice"), Player(name: "Ana")])
    let teamB = Team(players: [Player(name: "Bea"), Player(name: "Bob")])
    let state = MatchState(teamA: teamA, teamB: teamB)
    let record = MatchRecord.create(from: state)
    return NavigationStack {
        LiveMatchView(record: record, initialState: state)
    }
    .environmentObject(PhoneConnectivityManager.shared)
    .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
