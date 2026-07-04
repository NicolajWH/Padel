import XCTest
@testable import PadelKit

final class AmericanoTests: XCTestCase {

    func testScheduleCoversAllPlayersEachRound() {
        let players = (1...8).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings.standard(playerCount: players.count)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)

        XCTAssertEqual(rounds.count, settings.numberOfRounds)
        for round in rounds {
            var seen = Set<UUID>()
            for matchup in round.matchups {
                for player in matchup.teamA.players + matchup.teamB.players {
                    XCTAssertFalse(seen.contains(player.id), "Player appears twice in the same round")
                    seen.insert(player.id)
                }
            }
            XCTAssertEqual(seen.count, settings.numberOfCourts * 4)
        }
    }

    func testFourPlayersRotatePartnersEachRound() {
        let players = (1...4).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 21, numberOfCourts: 1, numberOfRounds: 3)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        XCTAssertEqual(rounds.count, 3)
        for round in rounds {
            XCTAssertEqual(round.matchups.count, 1)
        }
    }

    func testStandingsSumIndividualPoints() {
        let p1 = Player(name: "A"), p2 = Player(name: "B"), p3 = Player(name: "C"), p4 = Player(name: "D")
        let teamA = Team(players: [p1, p2])
        let teamB = Team(players: [p3, p4])
        var matchup = AmericanoMatchup(court: 1, teamA: teamA, teamB: teamB)
        for _ in 0..<21 { matchup.addPoint(to: .teamA, target: 21) }
        for _ in 0..<15 { matchup.addPoint(to: .teamB, target: 21) }

        let round = AmericanoRound(index: 0, matchups: [matchup])
        let session = AmericanoSession(players: [p1, p2, p3, p4], settings: AmericanoSettings(pointsPerRound: 21, numberOfCourts: 1, numberOfRounds: 1), rounds: [round])

        let standings = session.standings
        XCTAssertEqual(standings.first(where: { $0.player.id == p1.id })?.totalPoints, 21)
        XCTAssertEqual(standings.first(where: { $0.player.id == p3.id })?.totalPoints, 15)
        XCTAssertTrue(session.isRoundComplete(round))
        XCTAssertTrue(session.isComplete)
    }

    func testMatchupDoesNotExceedTargetAfterCompletion() {
        var matchup = AmericanoMatchup(court: 1, teamA: Team(players: [Player(name: "A"), Player(name: "B")]), teamB: Team(players: [Player(name: "C"), Player(name: "D")]))
        for _ in 0..<25 { matchup.addPoint(to: .teamA, target: 21) }
        let score = matchup.score(target: 21)
        XCTAssertEqual(score.a, 21)
        XCTAssertTrue(score.isComplete)
    }
}
