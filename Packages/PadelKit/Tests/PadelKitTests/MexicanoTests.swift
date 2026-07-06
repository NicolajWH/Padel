import XCTest
@testable import PadelKit

final class MexicanoTests: XCTestCase {

    private func makeSession(playerCount: Int, courts: Int = 1, rounds: Int = 5) -> AmericanoSession {
        let players = (1...playerCount).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 16, numberOfCourts: courts, numberOfRounds: rounds, format: .mexicano)
        return AmericanoSession(players: players, settings: settings, rounds: [])
    }

    /// Plays out the current round with fixed winners so standings are predictable.
    private func finishCurrentRound(_ session: inout AmericanoSession, winnerPoints: Int = 16, loserPoints: Int = 5) {
        let index = session.rounds.count - 1
        var round = session.rounds[index]
        for i in round.matchups.indices {
            for _ in 0..<(winnerPoints - 1) { round.matchups[i].addPoint(to: .teamA, target: winnerPoints) }
            for _ in 0..<loserPoints { round.matchups[i].addPoint(to: .teamB, target: winnerPoints) }
            round.matchups[i].addPoint(to: .teamA, target: winnerPoints)
        }
        session.rounds[index] = round
    }

    func testMexicanoGeneratesFirstRoundOnly() {
        var session = makeSession(playerCount: 8, courts: 2)
        XCTAssertTrue(session.appendNextRoundIfNeeded())
        XCTAssertEqual(session.rounds.count, 1)
        XCTAssertEqual(session.rounds[0].matchups.count, 2)
        // Next round must wait until the first one is finished.
        XCTAssertFalse(session.appendNextRoundIfNeeded())
        XCTAssertEqual(session.rounds.count, 1)
    }

    func testMexicanoPairsByStandings() {
        var session = makeSession(playerCount: 4)
        session.appendNextRoundIfNeeded()
        finishCurrentRound(&session)
        XCTAssertTrue(session.appendNextRoundIfNeeded())

        // After one round two players have 16 points and two have 5. Mexicano
        // seeds 1st+4th vs 2nd+3rd, so each new team must pair one winner
        // with one loser of the previous round.
        let standings = session.standings
        let topTwo = Set(standings.prefix(2).map(\.player.id))
        let newRound = session.rounds[1]
        for matchup in newRound.matchups {
            for team in [matchup.teamA, matchup.teamB] {
                let winnersOnTeam = team.players.filter { topTwo.contains($0.id) }.count
                XCTAssertEqual(winnersOnTeam, 1, "Each Mexicano team should mix a leader with a trailer")
            }
        }
    }

    func testMexicanoRoundGenerationIsDeterministic() {
        var sessionA = makeSession(playerCount: 8, courts: 2)
        sessionA.appendNextRoundIfNeeded()
        var sessionB = sessionA

        finishCurrentRound(&sessionA)
        finishCurrentRound(&sessionB)
        sessionA.appendNextRoundIfNeeded()
        sessionB.appendNextRoundIfNeeded()

        // The phone and the watch generate the next round independently; the
        // rounds must be byte-identical (including ids) for sync to converge.
        XCTAssertEqual(sessionA, sessionB)
    }

    func testMexicanoSessionCompletesAfterPlannedRounds() {
        var session = makeSession(playerCount: 4, rounds: 3)
        session.appendNextRoundIfNeeded()

        for _ in 0..<3 {
            XCTAssertFalse(session.isComplete)
            finishCurrentRound(&session)
            session.appendNextRoundIfNeeded()
        }
        XCTAssertEqual(session.rounds.count, 3)
        XCTAssertTrue(session.isComplete)
        XCTAssertFalse(session.appendNextRoundIfNeeded())
    }

    func testSitOutRotationIsFair() {
        // 5 players on one court: one player sits out per round. Over 5 rounds
        // everyone must sit out exactly once.
        var session = makeSession(playerCount: 5, rounds: 5)
        session.appendNextRoundIfNeeded()
        var sitOutCounts: [UUID: Int] = [:]
        for _ in 0..<5 {
            let round = session.rounds.last!
            for player in session.sittingOut(in: round) {
                sitOutCounts[player.id, default: 0] += 1
            }
            finishCurrentRound(&session)
            session.appendNextRoundIfNeeded()
        }
        XCTAssertEqual(sitOutCounts.count, 5)
        XCTAssertTrue(sitOutCounts.values.allSatisfy { $0 == 1 }, "Each of the 5 players should sit out exactly once, got \(sitOutCounts.values.sorted())")
    }

    func testAmericanoScheduleRotatesSitOutsFairly() {
        let players = (1...6).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 21, numberOfCourts: 1, numberOfRounds: 6, format: .americano)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        let session = AmericanoSession(players: players, settings: settings, rounds: rounds)

        var sitOutCounts: [UUID: Int] = [:]
        for round in rounds {
            for player in session.sittingOut(in: round) {
                sitOutCounts[player.id, default: 0] += 1
            }
        }
        // 6 players, 4 play per round, 6 rounds -> 12 sit-out slots, 2 per player.
        XCTAssertTrue(sitOutCounts.values.allSatisfy { $0 == 2 }, "Sit-outs should rotate evenly, got \(sitOutCounts.values.sorted())")
    }

    func testSettingsDecodeWithoutFormatFieldDefaultsToAmericano() throws {
        // Sessions saved before the format field existed must keep loading.
        let legacyJSON = #"{"pointsPerRound":21,"numberOfCourts":2,"numberOfRounds":5}"#
        let settings = try JSONDecoder().decode(AmericanoSettings.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(settings.format, .americano)
        XCTAssertEqual(settings.pointsPerRound, 21)

        let reencoded = try JSONEncoder().encode(settings)
        let roundTripped = try JSONDecoder().decode(AmericanoSettings.self, from: reencoded)
        XCTAssertEqual(roundTripped, settings)
    }

    func testGenerateScheduleForMexicanoReturnsOpeningRound() {
        let players = (1...8).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 16, numberOfCourts: 2, numberOfRounds: 5, format: .mexicano)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        XCTAssertEqual(rounds.count, 1, "Mexicano can only pre-generate the opening round")
        XCTAssertEqual(rounds[0].matchups.count, 2)
    }
}
