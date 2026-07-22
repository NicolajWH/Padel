import SwiftUI
import PadelKit

struct MatchSummaryView: View {
    let state: MatchState
    var onDone: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let snap = state.snapshot
        NavigationStack {
            ZStack {
                PadelTheme.scoreboardGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    if let winner = snap.winner {
                        VStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(PadelTheme.lime)
                                .shadow(color: PadelTheme.lime.opacity(0.6), radius: 16)
                            Text("\(state.team(winner).displayName) Wins!")
                                .font(.title2).bold()
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 32)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text(state.teamA.displayName).bold()
                                .foregroundStyle(PadelTheme.teamA)
                            Spacer()
                            Text(state.teamB.displayName).bold()
                                .foregroundStyle(PadelTheme.teamB)
                        }
                        Divider().overlay(.white.opacity(0.3))
                        ForEach(Array(snap.completedSets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text("Set \(index + 1)").foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text("\(set.teamAGames) - \(set.teamBGames)")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PadelTheme.lime)
                    .foregroundStyle(PadelTheme.night)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Match Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
