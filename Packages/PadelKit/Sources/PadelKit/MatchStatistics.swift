import Foundation

/// Lightweight head-to-head / form statistics derived from a collection of finished matches.
/// This is a nice-to-have surfaced in the iOS History and Player screens.
public struct PlayerMatchStats: Sendable {
    public var player: Player
    public var played: Int
    public var wins: Int
    public var losses: Int
    public var setsWon: Int
    public var setsLost: Int
    public var gamesWon: Int
    public var gamesLost: Int

    public var winRate: Double {
        played == 0 ? 0 : Double(wins) / Double(played)
    }
}

public enum MatchStatistics {
    public static func stats(for player: Player, in matches: [MatchState]) -> PlayerMatchStats {
        var stats = PlayerMatchStats(player: player, played: 0, wins: 0, losses: 0, setsWon: 0, setsLost: 0, gamesWon: 0, gamesLost: 0)

        for match in matches where match.isFinished {
            let onA = match.teamA.players.contains { $0.id == player.id }
            let onB = match.teamB.players.contains { $0.id == player.id }
            guard onA || onB else { continue }

            let side: TeamSide = onA ? .teamA : .teamB
            let snapshot = match.snapshot
            stats.played += 1
            if snapshot.winner == side {
                stats.wins += 1
            } else {
                stats.losses += 1
            }

            for set in snapshot.completedSets {
                let mine = side == .teamA ? set.teamAGames : set.teamBGames
                let theirs = side == .teamA ? set.teamBGames : set.teamAGames
                stats.gamesWon += mine
                stats.gamesLost += theirs
                if mine > theirs { stats.setsWon += 1 } else { stats.setsLost += 1 }
            }
        }

        return stats
    }
}
