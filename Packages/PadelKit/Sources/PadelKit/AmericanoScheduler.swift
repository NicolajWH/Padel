import Foundation

/// Generates Americano round schedules that try to give every player a fresh
/// partner (and a fresh opponent) as often as possible, using a greedy
/// balancing heuristic rather than a full combinatorial optimizer.
///
/// Mexicano rounds are generated one at a time from the live standings
/// instead: within each group of four (taken in standings order) the 1st and
/// 4th seed team up against the 2nd and 3rd, so games get more even as the
/// session progresses.
///
/// All generation that happens *after* setup (Mexicano next-rounds) is seeded
/// from the session id and round index, never from `SystemRandomNumberGenerator`,
/// so the iPhone and the Watch independently derive byte-identical rounds —
/// including the round/matchup UUIDs — and sync stays conflict-free.
public enum AmericanoScheduler {

    public static func generateSchedule(players: [Player], settings: AmericanoSettings) -> [AmericanoRound] {
        guard players.count >= 4 else { return [] }

        // Mexicano can only pre-generate the opening round; the rest depend on scores.
        if settings.format == .mexicano {
            var session = AmericanoSession(players: players, settings: settings, rounds: [])
            session.appendNextRoundIfNeeded()
            return session.rounds
        }

        let courts = max(1, settings.numberOfCourts)
        let playersPerRound = min(players.count, courts * 4)

        var partnerCount: [Set<UUID>: Int] = [:]
        var sitOutCount: [UUID: Int] = [:]
        var rounds: [AmericanoRound] = []

        for roundIndex in 0..<max(0, settings.numberOfRounds) {
            let usableCount = (min(playersPerRound, players.count) / 4) * 4
            guard usableCount >= 4 else { continue }

            // Rotate sit-outs fairly: whoever has sat out the least sits out
            // next, so nobody misses two rounds before everyone missed one.
            // Whoever has sat out the fewest times sits out next, so nobody
            // misses a second round before everyone has missed one.
            var rng = SystemRandomNumberGenerator()
            let ordered = players.shuffled(using: &rng).sorted {
                (sitOutCount[$0.id] ?? 0) < (sitOutCount[$1.id] ?? 0)
            }
            let sittingOut = ordered.prefix(players.count - usableCount)
            for player in sittingOut { sitOutCount[player.id, default: 0] += 1 }
            var activePool = Array(ordered.suffix(usableCount)).shuffled(using: &rng)

            var matchups: [AmericanoMatchup] = []
            var court = 1
            while activePool.count >= 4 {
                let group = Array(activePool.prefix(4))
                activePool.removeFirst(4)

                let (teamA, teamB) = bestSplit(of: group, partnerCount: partnerCount)
                partnerCount[Set(teamA.players.map(\.id)), default: 0] += 1
                partnerCount[Set(teamB.players.map(\.id)), default: 0] += 1

                matchups.append(AmericanoMatchup(court: court, teamA: teamA, teamB: teamB))
                court += 1
            }
            rounds.append(AmericanoRound(index: roundIndex, matchups: matchups))
        }
        return rounds
    }

    /// The next round for a session whose generated rounds are all finished,
    /// or nil if one can't be built. Deterministic for a given session state.
    public static func nextRound(for session: AmericanoSession) -> AmericanoRound? {
        let players = session.players
        guard players.count >= 4 else { return nil }

        let settings = session.settings
        let roundIndex = session.rounds.count
        let courts = max(1, settings.numberOfCourts)
        let usableCount = (min(players.count, courts * 4) / 4) * 4
        guard usableCount >= 4 else { return nil }

        var rng = SeededRandomNumberGenerator(seed: seed(sessionID: session.id, roundIndex: roundIndex))

        // Fair sit-out rotation, deterministic: seeded shuffle breaks ties,
        // and whoever has sat out the fewest times sits out next.
        var sitOutCount: [UUID: Int] = [:]
        for round in session.rounds {
            for player in session.sittingOut(in: round) {
                sitOutCount[player.id, default: 0] += 1
            }
        }
        let byRest = players.shuffled(using: &rng).sorted {
            (sitOutCount[$0.id] ?? 0) < (sitOutCount[$1.id] ?? 0)
        }
        let active = Set(byRest.suffix(usableCount).map(\.id))

        // Seeding order: opening round is a seeded shuffle; later rounds
        // follow the standings so close scores meet each other.
        let ordered: [Player]
        if session.rounds.isEmpty {
            ordered = players.shuffled(using: &rng).filter { active.contains($0.id) }
        } else {
            ordered = session.standings.map(\.player).filter { active.contains($0.id) }
        }

        var partnerCount: [Set<UUID>: Int] = [:]
        for round in session.rounds {
            for matchup in round.matchups {
                partnerCount[Set(matchup.teamA.players.map(\.id)), default: 0] += 1
                partnerCount[Set(matchup.teamB.players.map(\.id)), default: 0] += 1
            }
        }

        var matchups: [AmericanoMatchup] = []
        var pool = ordered
        var court = 1
        while pool.count >= 4 {
            let group = Array(pool.prefix(4))
            pool.removeFirst(4)

            let (teamA, teamB): (Team, Team)
            switch settings.format {
            case .mexicano:
                // Classic Mexicano split: 1st + 4th vs 2nd + 3rd.
                teamA = Team(players: [group[0], group[3]])
                teamB = Team(players: [group[1], group[2]])
            case .americano:
                (teamA, teamB) = bestSplit(of: group, partnerCount: partnerCount)
                partnerCount[Set(teamA.players.map(\.id)), default: 0] += 1
                partnerCount[Set(teamB.players.map(\.id)), default: 0] += 1
            }

            matchups.append(
                AmericanoMatchup(id: deterministicUUID(using: &rng), court: court, teamA: teamA, teamB: teamB)
            )
            court += 1
        }
        guard !matchups.isEmpty else { return nil }
        return AmericanoRound(id: deterministicUUID(using: &rng), index: roundIndex, matchups: matchups)
    }

    /// Of the three ways to split 4 people into two teams of 2, pick the one whose
    /// pairings have partnered together the fewest times so far.
    private static func bestSplit(of group: [Player], partnerCount: [Set<UUID>: Int]) -> (Team, Team) {
        guard group.count == 4 else {
            let mid = group.count / 2
            return (Team(players: Array(group.prefix(mid))), Team(players: Array(group.suffix(from: mid))))
        }

        let candidates: [((Player, Player), (Player, Player))] = [
            ((group[0], group[1]), (group[2], group[3])),
            ((group[0], group[2]), (group[1], group[3])),
            ((group[0], group[3]), (group[1], group[2]))
        ]

        var best = candidates[0]
        var bestScore = Int.max
        for candidate in candidates {
            let keyA: Set<UUID> = [candidate.0.0.id, candidate.0.1.id]
            let keyB: Set<UUID> = [candidate.1.0.id, candidate.1.1.id]
            let score = (partnerCount[keyA] ?? 0) + (partnerCount[keyB] ?? 0)
            if score < bestScore {
                bestScore = score
                best = candidate
            }
        }

        return (
            Team(players: [best.0.0, best.0.1]),
            Team(players: [best.1.0, best.1.1])
        )
    }

    private static func seed(sessionID: UUID, roundIndex: Int) -> UInt64 {
        let bytes = withUnsafeBytes(of: sessionID.uuid) { Array($0) }
        var value: UInt64 = 0
        for (offset, byte) in bytes.enumerated() {
            value ^= UInt64(byte) << (UInt64(offset % 8) * 8)
        }
        return value &+ (UInt64(roundIndex) &* 0x9E3779B97F4A7C15)
    }

    private static func deterministicUUID(using rng: inout SeededRandomNumberGenerator) -> UUID {
        let hi = rng.next()
        let lo = rng.next()
        var bytes = [UInt8]()
        for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: hi >> UInt64(shift))) }
        for shift in stride(from: 56, through: 0, by: -8) { bytes.append(UInt8(truncatingIfNeeded: lo >> UInt64(shift))) }
        // Stamp RFC 4122 version/variant bits so the result is a well-formed v4 UUID.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

/// SplitMix64 — tiny, fast, and identical across devices for the same seed,
/// which is all Mexicano round generation needs.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
