import SwiftUI
import PadelKit

struct WatchMatchResultView: View {
    let state: MatchState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let snap = state.snapshot
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(PadelTheme.lime)
                .font(.title2)
                .shadow(color: PadelTheme.lime.opacity(0.6), radius: 8)
            if let winner = snap.winner {
                Text("\(state.team(winner).displayName) Wins")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            Text(snap.completedSets.map { "\($0.teamAGames)-\($0.teamBGames)" }.joined(separator: "  "))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
        }
        .padding()
    }
}

#Preview {
    let state = MatchState(
        teamA: Team(players: [Player(name: "Alice"), Player(name: "Ana")]),
        teamB: Team(players: [Player(name: "Bea"), Player(name: "Bob")]),
        settings: .quickSingleSet
    )
    return WatchMatchResultView(state: state)
}
