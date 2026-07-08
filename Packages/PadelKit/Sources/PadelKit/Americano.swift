import Foundation

/// How players are matched up each round.
public enum AmericanoFormat: String, Codable, Hashable, Sendable, CaseIterable {
    /// Rotate partners and opponents so everyone plays with/against everyone.
    case americano
    /// Re-seed every round from the live standings so equally-scoring players
    /// meet each other: 1st + 4th vs 2nd + 3rd within each group of four.
    case mexicano

    public var displayName: String {
        switch self {
        case .americano: return "Americano"
        case .mexicano: return "Mexicano"
        }
    }
}

/// Configurable rules for an Americano tournament: everyone rotates partners
/// and opponents, and individual points accumulate across rounds.
public struct AmericanoSettings: Codable, Hashable, Sendable {
    /// Points a court race to in each round (classic Americano is a straight race, no deuce).
    public var pointsPerRound: Int
    /// How many courts play simultaneously each round.
    public var numberOfCourts: Int
    /// How many rounds to schedule.
    public var numberOfRounds: Int
    /// How matchups are generated each round.
    public var format: AmericanoFormat
    /// When true, players sign up as fixed pairs — partners stay together all
    /// session and only opponents rotate. Applies to both formats; individual
    /// points still accumulate per player.
    public var fixedPartners: Bool

    public init(pointsPerRound: Int = 21, numberOfCourts: Int = 1, numberOfRounds: Int = 3, format: AmericanoFormat = .americano, fixedPartners: Bool = false) {
        self.pointsPerRound = pointsPerRound
        self.numberOfCourts = numberOfCourts
        self.numberOfRounds = numberOfRounds
        self.format = format
        self.fixedPartners = fixedPartners
    }

    // Sessions saved before `format`/`fixedPartners` existed (on-watch
    // UserDefaults, SwiftData records, in-flight sync payloads) must keep
    // decoding, so newer fields are optional on the wire and fall back to
    // classic Americano defaults.
    private enum CodingKeys: String, CodingKey {
        case pointsPerRound, numberOfCourts, numberOfRounds, format, fixedPartners
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pointsPerRound = try container.decode(Int.self, forKey: .pointsPerRound)
        numberOfCourts = try container.decode(Int.self, forKey: .numberOfCourts)
        numberOfRounds = try container.decode(Int.self, forKey: .numberOfRounds)
        format = try container.decodeIfPresent(AmericanoFormat.self, forKey: .format) ?? .americano
        fixedPartners = try container.decodeIfPresent(Bool.self, forKey: .fixedPartners) ?? false
    }

    /// A sensible default given a player count: one court per 4 players, enough
    /// rounds to give everyone a good mix of partners.
    public static func standard(playerCount: Int) -> AmericanoSettings {
        let courts = max(1, playerCount / 4)
        let rounds = max(3, min(playerCount - 1, 10))
        return AmericanoSettings(pointsPerRound: 21, numberOfCourts: courts, numberOfRounds: rounds)
    }
}

public struct AmericanoMatchup: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var court: Int
    public var teamA: Team
    public var teamB: Team
    public var pointLog: [TeamSide]

    public init(id: UUID = UUID(), court: Int, teamA: Team, teamB: Team, pointLog: [TeamSide] = []) {
        self.id = id
        self.court = court
        self.teamA = teamA
        self.teamB = teamB
        self.pointLog = pointLog
    }

    /// Derived score, computed from the point log so watch/phone sync can never disagree.
    public func score(target: Int) -> (a: Int, b: Int, isComplete: Bool) {
        var a = 0, b = 0
        for point in pointLog {
            if a >= target || b >= target { break }
            if point == .teamA { a += 1 } else { b += 1 }
        }
        return (a, b, a >= target || b >= target)
    }

    public mutating func addPoint(to side: TeamSide, target: Int) {
        guard !score(target: target).isComplete else { return }
        pointLog.append(side)
    }

    public mutating func undoLastPoint() {
        guard !pointLog.isEmpty else { return }
        pointLog.removeLast()
    }
}

public struct AmericanoRound: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var index: Int
    public var matchups: [AmericanoMatchup]

    public init(id: UUID = UUID(), index: Int, matchups: [AmericanoMatchup]) {
        self.id = id
        self.index = index
        self.matchups = matchups
    }
}

public struct AmericanoStandingsEntry: Identifiable, Hashable, Sendable {
    public var id: UUID { player.id }
    public var player: Player
    public var totalPoints: Int
    public var roundsPlayed: Int
}

public struct AmericanoSession: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var players: [Player]
    public var settings: AmericanoSettings
    public var rounds: [AmericanoRound]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Americano",
        players: [Player],
        settings: AmericanoSettings,
        rounds: [AmericanoRound] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.players = players
        self.settings = settings
        self.rounds = rounds
        self.createdAt = createdAt
    }

    public func isRoundComplete(_ round: AmericanoRound) -> Bool {
        round.matchups.allSatisfy { $0.score(target: settings.pointsPerRound).isComplete }
    }

    /// Mexicano rounds are generated one at a time, so the session isn't over
    /// until every *planned* round exists and is finished — not just the
    /// rounds generated so far.
    public var isComplete: Bool {
        !rounds.isEmpty && rounds.count >= settings.numberOfRounds && rounds.allSatisfy { isRoundComplete($0) }
    }

    /// Total rounds this session will have once fully played.
    public var plannedRoundCount: Int {
        max(settings.numberOfRounds, rounds.count)
    }

    /// Players who don't play in the given round (more players than court slots).
    public func sittingOut(in round: AmericanoRound) -> [Player] {
        var playing = Set<UUID>()
        for matchup in round.matchups {
            for player in matchup.teamA.players + matchup.teamB.players {
                playing.insert(player.id)
            }
        }
        return players.filter { !playing.contains($0.id) }
    }

    /// Appends the next round when all generated rounds are finished but more
    /// are planned (how Mexicano sessions grow round by round). Generation is
    /// fully deterministic from the session state, so the iPhone and the Watch
    /// independently produce byte-identical rounds and stay in sync.
    @discardableResult
    public mutating func appendNextRoundIfNeeded() -> Bool {
        guard rounds.count < settings.numberOfRounds else { return false }
        guard rounds.allSatisfy({ isRoundComplete($0) }) else { return false }
        guard let next = AmericanoScheduler.nextRound(for: self) else { return false }
        rounds.append(next)
        return true
    }

    /// Index of the first round that still has unfinished matchups, or the last round if all are done.
    public var currentRoundIndex: Int {
        rounds.firstIndex { !isRoundComplete($0) } ?? max(0, rounds.count - 1)
    }

    public var standings: [AmericanoStandingsEntry] {
        var totals: [UUID: Int] = [:]
        var played: [UUID: Int] = [:]
        for round in rounds {
            for matchup in round.matchups {
                let s = matchup.score(target: settings.pointsPerRound)
                guard s.isComplete else { continue }
                for player in matchup.teamA.players {
                    totals[player.id, default: 0] += s.a
                    played[player.id, default: 0] += 1
                }
                for player in matchup.teamB.players {
                    totals[player.id, default: 0] += s.b
                    played[player.id, default: 0] += 1
                }
            }
        }
        // Ties are broken deterministically (name, then id) so Mexicano
        // seeding derived from these standings is identical on every device.
        return players
            .map { player in
                AmericanoStandingsEntry(
                    player: player,
                    totalPoints: totals[player.id] ?? 0,
                    roundsPlayed: played[player.id] ?? 0
                )
            }
            .sorted {
                if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
                if $0.player.name != $1.player.name { return $0.player.name < $1.player.name }
                return $0.player.id.uuidString < $1.player.id.uuidString
            }
    }
}
