import SwiftUI
import PadelKit

struct WatchMatchResultView: View {
    let state: MatchState
    /// Close the match and go back to the start menu.
    var onClose: () -> Void = {}
    /// Start a fresh match with the same teams and rules.
    var onRematch: () -> Void = {}

    var body: some View {
        let snap = state.snapshot
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PadelTheme.lime)
                    .font(.title2)
                    .shadow(color: PadelTheme.lime.opacity(0.6), radius: 8)
                if let winner = snap.winner {
                    Text("\(state.team(winner).shortDisplayName) Wins")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                Text(snap.completedSets.map { "\($0.teamAGames)-\($0.teamBGames)" }.joined(separator: "  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Button(action: onRematch) {
                        Label("Rematch", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(PadelTheme.teamA)

                    Button(action: onClose) {
                        Label("Done", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(PadelTheme.lime)
                }
                .padding(.top, 4)
            }
            .padding()
        }
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
