import XCTest
@testable import PadelKit

final class FixedPartnersTests: XCTestCase {

    /// The fixed pairs a roster is split into: consecutive players two at a time.
    private func pairKeys(_ players: [Player]) -> [Set<UUID>] {
        stride(from: 0, to: players.count - 1, by: 2).map {
            Set([players[$0].id, players[$0 + 1].id])
        }
    }

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

    // MARK: Americano with fixed partners

    func testFixedPartnersKeepPartnersTogetherEveryRound() {
        let players = (1...8).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 21, numberOfCourts: 2, numberOfRounds: 5, format: .americano, fixedPartners: true)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)

        XCTAssertEqual(rounds.count, 5)
        let allowedPairs = Set(pairKeys(players).map { $0 })
        for round in rounds {
            XCTAssertEqual(round.matchups.count, 2)
            for matchup in round.matchups {
                for team in [matchup.teamA, matchup.teamB] {
                    let key = Set(team.players.map(\.id))
                    XCTAssertTrue(allowedPairs.contains(key), "A team must always be one of the fixed pairs")
                }
            }
        }
    }

    func testFixedPartnersRotateOpponents() {
        // Four fixed pairs on two courts, three rounds — every pair should meet
        // each of the other three pairs exactly once (a round robin).
        let players = (1...8).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 21, numberOfCourts: 2, numberOfRounds: 3, format: .americano, fixedPartners: true)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)

        var faced: [Set<UUID>: Set<Set<UUID>>] = [:]
        for round in rounds {
            for matchup in round.matchups {
                let a = Set(matchup.teamA.players.map(\.id))
                let b = Set(matchup.teamB.players.map(\.id))
                faced[a, default: []].insert(b)
                faced[b, default: []].insert(a)
            }
        }
        for (_, opponents) in faced {
            XCTAssertEqual(opponents.count, 3, "Each pair should face all three other pairs across the rounds")
        }
    }

    func testFixedPartnersSitOutRotatesByPair() {
        // Three pairs on one court: a whole pair sits out each round, and over
        // three rounds every pair sits exactly once.
        let players = (1...6).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 21, numberOfCourts: 1, numberOfRounds: 3, format: .americano, fixedPartners: true)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        let session = AmericanoSession(players: players, settings: settings, rounds: rounds)

        var sitOut: [UUID: Int] = [:]
        for round in rounds {
            let sitting = session.sittingOut(in: round)
            XCTAssertEqual(sitting.count, 2, "A whole pair sits out together")
            XCTAssertTrue(pairKeys(players).contains(Set(sitting.map(\.id))), "The sit-outs are a fixed pair")
            for player in sitting { sitOut[player.id, default: 0] += 1 }
        }
        XCTAssertTrue(sitOut.values.allSatisfy { $0 == 1 }, "Every player sits out exactly once, got \(sitOut.values.sorted())")
    }

    // MARK: Mexicano with fixed partners

    func testMexicanoFixedPartnersGeneratesOpeningRoundOnly() {
        let players = (1...8).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 16, numberOfCourts: 2, numberOfRounds: 5, format: .mexicano, fixedPartners: true)
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        XCTAssertEqual(rounds.count, 1)
        XCTAssertEqual(rounds[0].matchups.count, 2)
        for matchup in rounds[0].matchups {
            for team in [matchup.teamA, matchup.teamB] {
                XCTAssertTrue(pairKeys(players).contains(Set(team.players.map(\.id))))
            }
        }
    }

    func testMexicanoFixedPartnersKeepsPairsAndIsDeterministic() {
        let players = (1...8).map { Player(name: "P\($0)") }
        let settings = AmericanoSettings(pointsPerRound: 16, numberOfCourts: 2, numberOfRounds: 4, format: .mexicano, fixedPartners: true)

        var sessionA = AmericanoSession(players: players, settings: settings, rounds: [])
        sessionA.appendNextRoundIfNeeded()
        var sessionB = sessionA

        for _ in 0..<3 {
            finishCurrentRound(&sessionA)
            finishCurrentRound(&sessionB)
            sessionA.appendNextRoundIfNeeded()
            sessionB.appendNextRoundIfNeeded()
        }

        // Pairs never split.
        let allowed = Set(pairKeys(players))
        for round in sessionA.rounds {
            for matchup in round.matchups {
                for team in [matchup.teamA, matchup.teamB] {
                    XCTAssertTrue(allowed.contains(Set(team.players.map(\.id))))
                }
            }
        }
        // Phone and watch derive identical rounds.
        XCTAssertEqual(sessionA, sessionB)
    }

    // MARK: Settings persistence

    func testSettingsDecodeWithoutFixedPartnersDefaultsFalse() throws {
        let legacyJSON = #"{"pointsPerRound":21,"numberOfCourts":2,"numberOfRounds":5,"format":"mexicano"}"#
        let settings = try JSONDecoder().decode(AmericanoSettings.self, from: Data(legacyJSON.utf8))
        XCTAssertFalse(settings.fixedPartners)

        var enabled = settings
        enabled.fixedPartners = true
        let roundTripped = try JSONDecoder().decode(AmericanoSettings.self, from: JSONEncoder().encode(enabled))
        XCTAssertTrue(roundTripped.fixedPartners)
    }
}
