import SwiftUI
import SwiftData
import PadelKit

struct PlayersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayerRecord.name) private var players: [SavedPlayerRecord]
    @State private var newPlayerName = ""
    @State private var showingAdd = false
    @State private var showingImport = false

    var body: some View {
        Group { if players.isEmpty { PlayersEmptyStateView(onImport: { showingImport = true }, onAddManually: { showingAdd = true }) } else { playerList } }
            .padelBackground().screenTitle("Players")
            .toolbar { ToolbarItem(placement: .primaryAction) { addMenu } }
            .alert("Add Player", isPresented: $showingAdd) {
                TextField("Name", text: $newPlayerName); Button("Cancel", role: .cancel) { newPlayerName = "" }; Button("Add") { addPlayer() }
            }
            .sheet(isPresented: $showingImport) { ImportPlayersView(existingNames: players.map(\.name)) }
    }

    private var addMenu: some View {
        Menu {
            Button { showingAdd = true } label: { Label("Add Player", systemImage: "person.badge.plus") }
            Button { showingImport = true } label: { Label("Import from list", systemImage: "square.and.arrow.down") }
        } label: { Image(systemName: "plus") }.accessibilityLabel("Add Player")
    }

    private var playerList: some View {
        let matches = allFinishedMatches()
        let sessions = allAmericanoSessions()
        let ratings = PlayerInsights.ratings(matches: matches, americanoSessions: sessions, seedRatings: seedRatings())
        let ranked = players.sorted { rating(for: $0, ratings: ratings) > rating(for: $1, ratings: ratings) }
        return ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, record in
                    NavigationLink { PlayerDetailView(record: record) } label: {
                        let stats = MatchStatistics.stats(for: record.asPlayer, in: matches)
                        PlayerRowCard(position: index + 1, player: record.asPlayer, matches: stats.played, wins: stats.wins, rating: ratingText(for: record, ratings: ratings))
                    }
                    .buttonStyle(PremiumPressStyle())
                    .contextMenu {
                        Button("Delete Player", systemImage: "trash", role: .destructive) { modelContext.delete(record) }
                    }
                }
            }.padding()
        }
    }

    private func seedRatings() -> [String: Double] { Dictionary(uniqueKeysWithValues: players.compactMap { record in record.ratingSeed.map { (PlayerKey.normalize(record.name), $0) } }) }
    private func rating(for record: SavedPlayerRecord, ratings: [PlayerRatingEntry]) -> Double { ratings.first(where: { $0.key == PlayerKey.normalize(record.name) })?.rating ?? record.ratingSeed ?? PlayerRatingEntry.defaultRating }
    private func ratingText(for record: SavedPlayerRecord, ratings: [PlayerRatingEntry]) -> String { rating(for: record, ratings: ratings).formatted(.number.precision(.fractionLength(1))) }
    private func addPlayer() { let name = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines); guard !name.isEmpty else { return }; modelContext.insert(SavedPlayerRecord(name: name)); newPlayerName = "" }
    private func allFinishedMatches() -> [MatchState] { ((try? modelContext.fetch(FetchDescriptor<MatchRecord>())) ?? []).compactMap(\.state) }
    private func allAmericanoSessions() -> [AmericanoSession] { ((try? modelContext.fetch(FetchDescriptor<AmericanoRecord>())) ?? []).compactMap(\.session) }
}

struct PlayerRowCard: View {
    let position: Int
    let player: Player
    let matches: Int
    let wins: Int
    let rating: String
    var body: some View {
        PremiumCard(cornerRadius: DesignSystem.Radius.compact, padding: 13) {
            HStack(spacing: 12) {
                Text("\(position)").font(.subheadline.bold().monospacedDigit()).foregroundStyle(position <= 3 ? DesignSystem.accentLime : DesignSystem.textSecondary).frame(width: 24)
                CartoonAvatarView(playerName: player.name, size: 42, accent: position <= 3 ? DesignSystem.accentLime : DesignSystem.padelBlue)
                VStack(alignment: .leading, spacing: 3) { Text(player.name).font(.headline).foregroundStyle(DesignSystem.textPrimary); Text("\(matches) matches · \(wins) wins").font(.caption).foregroundStyle(DesignSystem.textSecondary) }
                Spacer(minLength: 6)
                Text(rating).font(.subheadline.bold().monospacedDigit()).foregroundStyle(DesignSystem.padelBlue).padding(.horizontal, 9).padding(.vertical, 6).background(DesignSystem.padelBlue.opacity(0.12)).clipShape(Capsule())
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(DesignSystem.textSecondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

#Preview { NavigationStack { PlayersView() }.modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true) }
