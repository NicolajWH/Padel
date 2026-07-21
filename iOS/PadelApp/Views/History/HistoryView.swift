import SwiftUI
import SwiftData
import PadelKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MatchRecord.createdAt, order: .reverse) private var matches: [MatchRecord]
    @Query(sort: \AmericanoRecord.createdAt, order: .reverse) private var americanos: [AmericanoRecord]

    var body: some View {
        List {
            Section("Matches") {
                if matches.isEmpty {
                    Text("No matches yet").foregroundStyle(.secondary)
                } else {
                    ForEach(matches) { record in
                        if let state = record.state {
                            NavigationLink {
                                record.isFinished ? AnyView(MatchSummaryView(state: state)) : AnyView(LiveMatchView(record: record, initialState: state))
                            } label: {
                                MatchRowView(state: state, showsChevron: false)
                            }
                        }
                    }
                    .onDelete { offsets in delete(matches, at: offsets) }
                }
            }

            Section("Americano Sessions") {
                if americanos.isEmpty {
                    Text("No Americano sessions yet").foregroundStyle(.secondary)
                } else {
                    ForEach(americanos) { record in
                        if let session = record.session {
                            NavigationLink {
                                AmericanoStandingsView(record: record, session: session)
                            } label: {
                                AmericanoRowView(session: session)
                            }
                        }
                    }
                    .onDelete { offsets in delete(americanos, at: offsets) }
                }
            }
        }
        .screenTitle("History")
    }

    private func delete<T: PersistentModel>(_ items: [T], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

struct AmericanoRowView: View {
    let session: AmericanoSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name).font(.subheadline).bold()
            HStack(spacing: 6) {
                Text("\(session.settings.format.displayName) · \(session.players.count) players · \(session.plannedRoundCount) rounds")
                if session.isComplete, let leader = session.standings.first {
                    Text("\(leader.player.name) won").foregroundStyle(.green)
                } else if !session.rounds.isEmpty {
                    StatusPill(text: "In progress", color: .orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
