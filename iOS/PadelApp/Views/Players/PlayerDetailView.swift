import SwiftUI
import SwiftData
import PadelKit

/// Everything the saved history knows about one player: rating, overall
/// record, chemistry with each partner, and head-to-head records.
struct PlayerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let player: Player

    @State private var matches: [MatchState] = []
    @State private var americanoSessions: [AmericanoSession] = []

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    PlayerAvatar(player: player, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name).font(.title3.bold())
                        if let rating {
                            Text("Rating \(rating.roundedRating) · \(rating.gamesRated) rated games")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No rated games yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let rank {
                        RankBadge(rank: rank)
                    }
                }
            } footer: {
                Text("Ratings start at \(Int(PlayerRatingEntry.baseRating)) and move after every match and Americano round — beating a stronger team counts for more.")
            }

            if stats.played > 0 {
                Section("Matches") {
                    LabeledContent("Record", value: "\(stats.wins)–\(stats.losses)")
                    LabeledContent("Win rate", value: stats.winRate.formatted(.percent.precision(.fractionLength(0))))
                    LabeledContent("Sets", value: "\(stats.setsWon)–\(stats.setsLost)")
                    LabeledContent("Games", value: "\(stats.gamesWon)–\(stats.gamesLost)")
                }
            }

            if !partners.isEmpty {
                Section {
                    ForEach(partners.prefix(8)) { record in
                        HStack {
                            PlayerAvatar(player: record.partner, size: 28)
                            Text(record.partner.name)
                            Spacer()
                            Text("\(record.wins)–\(record.losses)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(record.wins >= record.losses ? Color.green : .secondary)
                        }
                    }
                } header: {
                    Text("Partner Chemistry")
                } footer: {
                    Text("Wins–losses when teaming up, across matches and Americano rounds.")
                }
            }

            if !headToHead.isEmpty {
                Section("Head-to-Head") {
                    ForEach(headToHead.prefix(8)) { record in
                        HStack {
                            PlayerAvatar(player: record.opponent, size: 28)
                            Text(record.opponent.name)
                            Spacer()
                            Text("\(record.wins)–\(record.losses)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(record.wins >= record.losses ? Color.green : .secondary)
                        }
                    }
                }
            }

            if stats.played == 0 && partners.isEmpty && headToHead.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "figure.tennis",
                    description: Text("Play a match or an Americano with \(player.name) and their stats will show up here.")
                )
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadHistory)
    }

    private var stats: PlayerMatchStats {
        MatchStatistics.stats(for: player, in: matches)
    }

    private var partners: [PartnerRecord] {
        PlayerInsights.partnerStats(for: player, matches: matches, americanoSessions: americanoSessions)
    }

    private var headToHead: [HeadToHeadRecord] {
        PlayerInsights.headToHead(for: player, matches: matches, americanoSessions: americanoSessions)
    }

    private var allRatings: [PlayerRatingEntry] {
        PlayerInsights.ratings(matches: matches, americanoSessions: americanoSessions)
    }

    private var rating: PlayerRatingEntry? {
        allRatings.first { $0.key == PlayerKey.normalize(player.name) }
    }

    private var rank: Int? {
        guard let index = allRatings.firstIndex(where: { $0.key == PlayerKey.normalize(player.name) }) else { return nil }
        return index + 1
    }

    private func loadHistory() {
        let matchRecords = (try? modelContext.fetch(FetchDescriptor<MatchRecord>())) ?? []
        matches = matchRecords.compactMap { $0.state }
        let americanoRecords = (try? modelContext.fetch(FetchDescriptor<AmericanoRecord>())) ?? []
        americanoSessions = americanoRecords.compactMap { $0.session }
    }
}

#Preview {
    NavigationStack { PlayerDetailView(player: Player(name: "Nicolaj")) }
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
