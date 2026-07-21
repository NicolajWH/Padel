import XCTest
@testable import PadelKit

final class MatchEngineTests: XCTestCase {

    func makeTeams() -> (Team, Team) {
        let a = Team(players: [Player(name: "Alice"), Player(name: "Ana")])
        let b = Team(players: [Player(name: "Bea"), Player(name: "Bob")])
        return (a, b)
    }

    func testLoveGameWin() {
        let log: [TeamSide] = [.teamA, .teamA, .teamA, .teamA]
        let snap = MatchEngine.simulate(settings: .standard, pointLog: log)
        XCTAssertEqual(snap.currentSetGamesA, 1)
        XCTAssertEqual(snap.gamePointLabelA, "0")
    }

    func testDeuceAndAdvantage() {
        // 3 points each -> deuce (40-40)
        let log: [TeamSide] = [.teamA, .teamB, .teamA, .teamB, .teamA, .teamB]
        var snap = MatchEngine.simulate(settings: .standard, pointLog: log)
        XCTAssertEqual(snap.gamePointLabelA, "40")
        XCTAssertEqual(snap.gamePointLabelB, "40")

        snap = MatchEngine.simulate(settings: .standard, pointLog: log + [.teamA])
        XCTAssertEqual(snap.gamePointLabelA, "AD")
        XCTAssertEqual(snap.gamePointLabelB, "40")

        // Opponent equalizes back to deuce
        snap = MatchEngine.simulate(settings: .standard, pointLog: log + [.teamA, .teamB])
        XCTAssertEqual(snap.gamePointLabelA, "40")
        XCTAssertEqual(snap.gamePointLabelB, "40")

        // Win from advantage
        snap = MatchEngine.simulate(settings: .standard, pointLog: log + [.teamA, .teamA])
        XCTAssertEqual(snap.currentSetGamesA, 1)
    }

    func testGoldenPointSuddenDeath() {
        let log: [TeamSide] = [.teamA, .teamB, .teamA, .teamB, .teamA, .teamB, .teamA]
        let snap = MatchEngine.simulate(settings: .goldenPointBestOf3, pointLog: log)
        XCTAssertEqual(snap.currentSetGamesA, 1, "Golden point should win immediately at 40-40 without advantage")
    }

    func testSetGoesToTiebreakAtSixAll() {
        var log: [TeamSide] = []
        for _ in 0..<6 {
            log.append(contentsOf: [.teamA, .teamA, .teamA, .teamA]) // A wins game
            log.append(contentsOf: [.teamB, .teamB, .teamB, .teamB]) // B wins game
        }
        let snap = MatchEngine.simulate(settings: .standard, pointLog: log)
        XCTAssertEqual(snap.currentSetGamesA, 6)
        XCTAssertEqual(snap.currentSetGamesB, 6)
        XCTAssertTrue(snap.isTiebreak)
    }

    func testTiebreakWinClosesSet() {
        var log: [TeamSide] = []
        for _ in 0..<6 {
            log.append(contentsOf: [.teamA, .teamA, .teamA, .teamA])
            log.append(contentsOf: [.teamB, .teamB, .teamB, .teamB])
        }
        log.append(contentsOf: Array(repeating: TeamSide.teamA, count: 7))
        let snap = MatchEngine.simulate(settings: .standard, pointLog: log)
        XCTAssertEqual(snap.completedSets.count, 1)
        XCTAssertEqual(snap.completedSets[0].teamAGames, 7)
        XCTAssertEqual(snap.completedSets[0].teamBGames, 6)
        XCTAssertEqual(snap.setsWonA, 1)
    }

    func testMatchWinnerAfterTwoSets() {
        func gameLog(winner: TeamSide, count: Int) -> [TeamSide] {
            var log: [TeamSide] = []
            for _ in 0..<count {
                log.append(contentsOf: Array(repeating: winner, count: 4))
            }
            return log
        }
        // A wins set 1 6-0, set 2 6-0 -> match over
        let log = gameLog(winner: .teamA, count: 6) + gameLog(winner: .teamA, count: 6)
        let snap = MatchEngine.simulate(settings: .standard, pointLog: log)
        XCTAssertEqual(snap.winner, .teamA)
        XCTAssertTrue(snap.isMatchOver)
        XCTAssertEqual(snap.setsWonA, 2)
    }

    /// Six games each, alternating, so the set reaches 6-6 and enters a tiebreak
    /// with teamA as the first tiebreak server.
    private func sixAllLog() -> [TeamSide] {
        var log: [TeamSide] = []
        for _ in 0..<6 {
            log.append(contentsOf: [.teamA, .teamA, .teamA, .teamA])
            log.append(contentsOf: [.teamB, .teamB, .teamB, .teamB])
        }
        return log
    }

    func testTiebreakServeRotatesEveryTwoPointsAfterFirst() {
        let base = sixAllLog()
        XCTAssertTrue(MatchEngine.simulate(settings: .standard, pointLog: base).isTiebreak)

        // Split the tiebreak points evenly so it never ends mid-test; the serving
        // side depends only on how many points have been played.
        func server(afterTiebreakPoints n: Int) -> TeamSide {
            let tb = (0..<n).map { $0 % 2 == 0 ? TeamSide.teamA : .teamB }
            return MatchEngine.simulate(settings: .standard, pointLog: base + tb).servingSide
        }

        XCTAssertEqual(server(afterTiebreakPoints: 0), .teamA, "First tiebreak point is served by the first server")
        XCTAssertEqual(server(afterTiebreakPoints: 1), .teamB, "Serve flips after the first point")
        XCTAssertEqual(server(afterTiebreakPoints: 2), .teamB, "Each turn after the first is two points")
        XCTAssertEqual(server(afterTiebreakPoints: 3), .teamA, "Serve flips back after two points")
        XCTAssertEqual(server(afterTiebreakPoints: 4), .teamA)
        XCTAssertEqual(server(afterTiebreakPoints: 5), .teamB)
    }

    func testTiebreakServingPlayerContinuesRotation() {
        let base = sixAllLog()

        func playerIndex(afterTiebreakPoints n: Int) -> Int {
            let tb = (0..<n).map { $0 % 2 == 0 ? TeamSide.teamA : .teamB }
            return MatchEngine.simulate(settings: .standard, pointLog: base + tb).servingPlayerIndex
        }

        // Each team served six even-parity service games, so their first tiebreak
        // turn keeps player index 0; a team's next turn advances to its other player.
        XCTAssertEqual(playerIndex(afterTiebreakPoints: 0), 0)
        XCTAssertEqual(playerIndex(afterTiebreakPoints: 1), 0)
        XCTAssertEqual(playerIndex(afterTiebreakPoints: 3), 1, "teamA's second tiebreak turn uses the other player")
    }

    func testUndoRemovesLastPoint() {
        var match = MatchState(teamA: makeTeams().0, teamB: makeTeams().1)
        match.addPoint(for: .teamA)
        match.addPoint(for: .teamA)
        XCTAssertEqual(match.snapshot.gamePointLabelA, "30")
        match.undoLastPoint()
        XCTAssertEqual(match.snapshot.gamePointLabelA, "15")
    }

    func testCurrentServerCanBeChangedWithoutChangingScore() {
        let (teamA, teamB) = makeTeams()
        var match = MatchState(teamA: teamA, teamB: teamB)
        for _ in 0..<4 { match.addPoint(for: .teamA) }
        let scoreBefore = match.pointLog
        let selectedServer = teamA.players[1]

        match.setCurrentServer(playerID: selectedServer.id)

        XCTAssertEqual(match.currentServingPlayer?.id, selectedServer.id)
        XCTAssertEqual(match.pointLog, scoreBefore)
    }

    func testCurrentServerCanMoveToOtherTeam() {
        let (teamA, teamB) = makeTeams()
        var match = MatchState(teamA: teamA, teamB: teamB)
        let selectedServer = teamB.players[1]

        match.setCurrentServer(playerID: selectedServer.id)

        XCTAssertEqual(match.snapshot.servingSide, .teamB)
        XCTAssertEqual(match.currentServingPlayer?.id, selectedServer.id)
    }

    func testPointsIgnoredAfterMatchOver() {
        var match = MatchState(teamA: makeTeams().0, teamB: makeTeams().1, settings: .quickSingleSet)
        for _ in 0..<6 {
            match.addPoint(for: .teamA)
            match.addPoint(for: .teamA)
            match.addPoint(for: .teamA)
            match.addPoint(for: .teamA)
        }
        XCTAssertTrue(match.isFinished)
        let countBefore = match.pointLog.count
        match.addPoint(for: .teamB)
        XCTAssertEqual(match.pointLog.count, countBefore, "No points should be recorded once the match is over")
    }
}
