import SwiftUI
import PadelKit

struct MatchSummaryView: View {
    let state: MatchState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let snap = state.snapshot
        NavigationStack {
            VStack(spacing: 24) {
                if let winner = snap.winner {
                    VStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.yellow)
                        Text("\(state.team(winner).displayName) Wins!")
                            .font(.title2).bold()
                    }
                    .padding(.top, 32)
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(state.teamA.displayName).bold()
                        Spacer()
                        Text(state.teamB.displayName).bold()
                    }
                    Divider()
                    ForEach(Array(snap.completedSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(set.teamAGames) - \(set.teamBGames)")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 32)
            }
            .navigationTitle("Match Result")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let teamA = Team(players: [Player(name: "Alice"), Player(name: "Ana")])
    let teamB = Team(players: [Player(name: "Bea"), Player(name: "Bob")])
    var state = MatchState(teamA: teamA, teamB: teamB, settings: .quickSingleSet)
    for _ in 0..<6 { state.addPoint(for: .teamA); state.addPoint(for: .teamA); state.addPoint(for: .teamA); state.addPoint(for: .teamA) }
    return MatchSummaryView(state: state)
}
