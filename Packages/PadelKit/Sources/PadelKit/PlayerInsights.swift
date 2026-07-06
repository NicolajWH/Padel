import Foundation

/// Players are re-created with fresh UUIDs every time a match or Americano is
/// set up, so the only stable identity across the saved history is the name.
/// Everything that aggregates across sessions keys players by normalized name.
public enum PlayerKey {
    public static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func isSamePlayer(_ a: Player, as b: Player) -> Bool {
        a.id == b.id || normalize(a.name) == normalize(b.name)
    }
}

/// Win/loss record against one specific opponent.
public struct HeadToHeadRecord: Sendable, Identifiable, Hashable {
    public var id: String { PlayerKey.normalize(opponent.name) }
    public var opponent: Player
    public var wins: Int
    public var losses: Int

    public var played: Int { wins + losses }
}

/// Win/loss record alongside one specific partner.
public struct PartnerRecord: Sendable, Identifiable, Hashable {
    public var id: String { PlayerKey.normalize(partner.name) }
    public var partner: Player
    public var wins: Int
    public var losses: Int

    public var played: Int { wins + losses }
    public var winRate: Double { played == 0 ? 0 : Double(wins) / Double(played) }
}

/// A single decided doubles game — a finished match or a completed Americano
/// matchup — reduced to the two team rosters and who won.
struct DecidedGame {
    var date: Date
    var winners: [Player]
    var losers: [Player]
    /// Full matches move the rating more than one quick Americano round.
    var isFullMatch: Bool
}

public enum PlayerInsights {

    /// Every player's rating on the official 1–7 padel scale used on MATCHi,
    /// computed chronologically from the whole saved history.
    ///
    /// Each player starts from their manually set rating in `seedRatings`
    /// (keyed by normalized name), or the default level when none is set, and
    /// the rating is then adjusted after every game — beating a stronger team
    /// moves it more than beating a weaker one, and it always stays in 1...7.
    public static func ratings(
        matches: [MatchState],
        americanoSessions: [AmericanoSession] = [],
        seedRatings: [String: Double] = [:]
    ) -> [PlayerRatingEntry] {
        var ratings: [String: PlayerRatingEntry] = [:]

        func entry(for player: Player) -> PlayerRatingEntry {
            let key = PlayerKey.normalize(player.name)
            if let existing = ratings[key] { return existing }
            let start = seedRatings[key].map(PlayerRatingEntry.clamp) ?? PlayerRatingEntry.defaultRating
            return PlayerRatingEntry(key: key, player: player, rating: start, gamesRated: 0)
        }

        for game in decidedGames(matches: matches, americanoSessions: americanoSessions).sorted(by: { $0.date < $1.date }) {
            guard !game.winners.isEmpty, !game.losers.isEmpty else { continue }
            let winnerEntries = game.winners.map(entry(for:))
            let loserEntries = game.losers.map(entry(for:))

            let winnerAverage = winnerEntries.map(\.rating).reduce(0, +) / Double(winnerEntries.count)
            let loserAverage = loserEntries.map(\.rating).reduce(0, +) / Double(loserEntries.count)
            let expectedWin = 1.0 / (1.0 + pow(10, (loserAverage - winnerAverage) / PlayerRatingEntry.ratingScale))
            let k: Double = game.isFullMatch ? PlayerRatingEntry.matchK : PlayerRatingEntry.roundK
            let delta = k * (1 - expectedWin)

            for var entry in winnerEntries {
                entry.rating = PlayerRatingEntry.clamp(entry.rating + delta)
                entry.gamesRated += 1
                ratings[entry.key] = entry
            }
            for var entry in loserEntries {
                entry.rating = PlayerRatingEntry.clamp(entry.rating - delta)
                entry.gamesRated += 1
                ratings[entry.key] = entry
            }
        }

        return ratings.values.sorted { $0.rating > $1.rating }
    }

    /// Win/loss record against each opponent the player has faced.
    public static func headToHead(
        for player: Player,
        matches: [MatchState],
        americanoSessions: [AmericanoSession] = []
    ) -> [HeadToHeadRecord] {
        var records: [String: HeadToHeadRecord] = [:]

        for game in decidedGames(matches: matches, americanoSessions: americanoSessions) {
            let won = game.winners.contains { PlayerKey.isSamePlayer($0, as: player) }
            let lost = game.losers.contains { PlayerKey.isSamePlayer($0, as: player) }
            guard won != lost else { continue }
            for opponent in won ? game.losers : game.winners {
                let key = PlayerKey.normalize(opponent.name)
                var record = records[key] ?? HeadToHeadRecord(opponent: opponent, wins: 0, losses: 0)
                if won { record.wins += 1 } else { record.losses += 1 }
                records[key] = record
            }
        }

        return records.values.sorted { $0.played > $1.played }
    }

    /// Win rate alongside each partner the player has teamed up with.
    public static func partnerStats(
        for player: Player,
        matches: [MatchState],
        americanoSessions: [AmericanoSession] = []
    ) -> [PartnerRecord] {
        var records: [String: PartnerRecord] = [:]

        for game in decidedGames(matches: matches, americanoSessions: americanoSessions) {
            let won = game.winners.contains { PlayerKey.isSamePlayer($0, as: player) }
            let lost = game.losers.contains { PlayerKey.isSamePlayer($0, as: player) }
            guard won != lost else { continue }
            let teammates = (won ? game.winners : game.losers).filter { !PlayerKey.isSamePlayer($0, as: player) }
            for partner in teammates {
                let key = PlayerKey.normalize(partner.name)
                var record = records[key] ?? PartnerRecord(partner: partner, wins: 0, losses: 0)
                if won { record.wins += 1 } else { record.losses += 1 }
                records[key] = record
            }
        }

        return records.values.sorted { $0.played > $1.played }
    }

    static func decidedGames(matches: [MatchState], americanoSessions: [AmericanoSession]) -> [DecidedGame] {
        var games: [DecidedGame] = []

        for match in matches where match.isFinished {
            guard let winner = match.snapshot.winner else { continue }
            games.append(DecidedGame(
                date: match.createdAt,
                winners: match.team(winner).players,
                losers: match.team(winner == .teamA ? .teamB : .teamA).players,
                isFullMatch: true
            ))
        }

        for session in americanoSessions {
            for (roundOffset, round) in session.rounds.enumerated() {
                for matchup in round.matchups {
                    let score = matchup.score(target: session.settings.pointsPerRound)
                    guard score.isComplete, score.a != score.b else { continue }
                    let teamAWon = score.a > score.b
                    games.append(DecidedGame(
                        // Spread rounds a second apart so rating updates keep round order.
                        date: session.createdAt.addingTimeInterval(TimeInterval(roundOffset)),
                        winners: (teamAWon ? matchup.teamA : matchup.teamB).players,
                        losers: (teamAWon ? matchup.teamB : matchup.teamA).players,
                        isFullMatch: false
                    ))
                }
            }
        }

        return games
    }
}

/// One player's rating on the official 1–7 padel scale (as used on MATCHi),
/// computed over the whole saved history.
public struct PlayerRatingEntry: Sendable, Identifiable, Hashable {
    /// Bounds of the official padel scale.
    public static let minRating: Double = 1.0
    public static let maxRating: Double = 7.0
    /// Where a player lands before any manual seed or games — a mid-club level.
    public static let defaultRating: Double = 3.0
    /// Logistic divisor: a 2.0 rating gap makes the stronger team a ~91% favorite.
    static let ratingScale: Double = 2.0
    /// A full match moves the rating twice as much as a single Americano round.
    static let matchK: Double = 0.2
    static let roundK: Double = 0.1

    /// Keeps a rating inside the official 1...7 range.
    public static func clamp(_ value: Double) -> Double {
        min(max(value, minRating), maxRating)
    }

    public var id: String { key }
    public let key: String
    public var player: Player
    public var rating: Double
    public var gamesRated: Int

    /// The rating shown to players, e.g. "3.4" (localized separator).
    public var displayRating: String {
        rating.formatted(.number.precision(.fractionLength(1)))
    }
}
