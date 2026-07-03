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

    func testUndoRemovesLastPoint() {
        var match = MatchState(teamA: makeTeams().0, teamB: makeTeams().1)
        match.addPoint(for: .teamA)
        match.addPoint(for: .teamA)
        XCTAssertEqual(match.snapshot.gamePointLabelA, "30")
        match.undoLastPoint()
        XCTAssertEqual(match.snapshot.gamePointLabelA, "15")
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
