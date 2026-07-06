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
                let matches = allFinishedMatches()
                let ratings = PlayerInsights.ratings(matches: matches, americanoSessions: allAmericanoSessions(), seedRatings: seedRatings())
                ForEach(players) { record in
                    NavigationLink {
                        PlayerDetailView(record: record)
                    } label: {
                        HStack {
                            PlayerAvatar(player: record.asPlayer)
                            VStack(alignment: .leading) {
                                Text(record.name).font(.headline)
                                let stats = MatchStatistics.stats(for: record.asPlayer, in: matches)
                                if stats.played > 0 {
                                    Text("\(stats.wins) wins · \(stats.losses) losses")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No matches yet").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(ratingText(for: record, ratings: ratings))
                                .font(.subheadline.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
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

    /// Manual starting ratings keyed by normalized name, fed into the rating
    /// calculation so seeded players begin from their official 1–7 level.
    private func seedRatings() -> [String: Double] {
        var seeds: [String: Double] = [:]
        for record in players {
            if let seed = record.ratingSeed {
                seeds[PlayerKey.normalize(record.name)] = seed
            }
        }
        return seeds
    }

    /// The computed rating if the player has rated games, otherwise their
    /// manual seed, otherwise the starting rating everyone begins at.
    private func ratingText(for record: SavedPlayerRecord, ratings: [PlayerRatingEntry]) -> String {
        if let entry = ratings.first(where: { $0.key == PlayerKey.normalize(record.name) }) {
            return entry.displayRating
        }
        let start = record.ratingSeed ?? PlayerRatingEntry.defaultRating
        return start.formatted(.number.precision(.fractionLength(1)))
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

    private func allAmericanoSessions() -> [AmericanoSession] {
        let descriptor = FetchDescriptor<AmericanoRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap { $0.session }
    }
}

#Preview {
    NavigationStack { PlayersView() }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
