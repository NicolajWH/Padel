import Foundation

/// Generates Americano round schedules that try to give every player a fresh
/// partner (and a fresh opponent) as often as possible, using a greedy
/// balancing heuristic rather than a full combinatorial optimizer.
public enum AmericanoScheduler {

    public static func generateSchedule(players: [Player], settings: AmericanoSettings) -> [AmericanoRound] {
        guard players.count >= 4 else { return [] }

        let courts = max(1, settings.numberOfCourts)
        let playersPerRound = min(players.count, courts * 4)

        var partnerCount: [Set<UUID>: Int] = [:]
        var rounds: [AmericanoRound] = []

        for roundIndex in 0..<max(0, settings.numberOfRounds) {
            var pool = players.shuffled()
            let usableCount = (min(playersPerRound, pool.count) / 4) * 4
            guard usableCount >= 4 else { continue }
            var activePool = Array(pool.prefix(usableCount))
            pool.removeAll()

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
}
