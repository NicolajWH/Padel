import SwiftUI
import SwiftData
import PadelKit

struct PlayersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var players: [SavedPlayerRecord]
    @State private var newPlayerName = ""
    @State private var showingAdd = false

    var body: some View {
        List {
            if players.isEmpty {
                ContentUnavailableView(
                    "No Players Yet",
                    systemImage: "person.badge.plus",
                    description: Text("Add players so you can quickly pick them when starting a match or Americano.")
                )
            } else {
                ForEach(players) { record in
                    HStack {
                        PlayerAvatar(player: record.asPlayer)
                        VStack(alignment: .leading) {
                            Text(record.name).font(.headline)
                            let stats = MatchStatistics.stats(for: record.asPlayer, in: allFinishedMatches())
                            if stats.played > 0 {
                                Text("\(stats.wins)W – \(stats.losses)L · \(Int(stats.winRate * 100))% win rate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No matches yet").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Players")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Player", isPresented: $showingAdd) {
            TextField("Name", text: $newPlayerName)
            Button("Cancel", role: .cancel) { newPlayerName = "" }
            Button("Add") { addPlayer() }
        }
    }

    private func addPlayer() {
        let trimmed = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let record = SavedPlayerRecord(name: trimmed)
        modelContext.insert(record)
        newPlayerName = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
    }

    private func allFinishedMatches() -> [MatchState] {
        let descriptor = FetchDescriptor<MatchRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap { $0.state }
    }
}

#Preview {
    NavigationStack { PlayersView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
