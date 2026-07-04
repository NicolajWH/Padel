import SwiftUI
import SwiftData
import PadelKit

struct PlayHomeView: View {
    @Query(sort: \MatchRecord.createdAt, order: .reverse) private var matches: [MatchRecord]

    private var ongoingMatch: MatchRecord? {
        matches.first { !$0.isFinished }
    }

    var body: some View {
        List {
            if let ongoingMatch, let state = ongoingMatch.state {
                Section("Continue") {
                    NavigationLink {
                        LiveMatchView(record: ongoingMatch, initialState: state)
                    } label: {
                        MatchRowView(state: state)
                    }
                }
            }

            Section {
                NavigationLink {
                    NewMatchSetupView()
                } label: {
                    Label("New Match", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            } footer: {
                Text("Score a padel match with real scoring rules — deuce or golden point, sets and tiebreaks. Sync live to your Apple Watch.")
            }

            if !matches.isEmpty {
                Section("Recent") {
                    ForEach(matches.prefix(5)) { record in
                        if let state = record.state {
                            NavigationLink {
                                record.isFinished ? AnyView(MatchSummaryView(state: state)) : AnyView(LiveMatchView(record: record, initialState: state))
                            } label: {
                                MatchRowView(state: state)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Play")
    }
}

struct MatchRowView: View {
    let state: MatchState

    var body: some View {
        let snap = state.snapshot
        VStack(alignment: .leading, spacing: 4) {
            Text("\(state.teamA.displayName) vs \(state.teamB.displayName)")
                .font(.subheadline).bold()
            HStack {
                Text("Sets \(snap.setsWonA)-\(snap.setsWonB)")
                if !state.isFinished {
                    Text("· In progress").foregroundStyle(.orange)
                } else if let winner = snap.winner {
                    Text("· \(state.team(winner).displayName) won").foregroundStyle(.green)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { PlayHomeView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
