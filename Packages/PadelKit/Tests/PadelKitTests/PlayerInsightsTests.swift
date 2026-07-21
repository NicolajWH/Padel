import XCTest
@testable import PadelKit

final class PlayerInsightsTests: XCTestCase {
    func testPlayerRosterSyncPayloadRoundTripsOwnerAndPlayers() throws {
        let owner = Player(name: "Nicolaj Worsa")
        let friend = Player(name: "Anna Berg")
        let payload = SyncPayload.playerRoster(PlayerRoster(players: [owner, friend], ownerID: owner.id))

        guard case .playerRoster(let decoded) = SyncPayload.decode(payload.encoded()) else {
            return XCTFail("Expected a player roster payload")
        }
        XCTAssertEqual(decoded.players, [owner, friend])
        XCTAssertEqual(decoded.ownerID, owner.id)
    }


    /// Builds a finished best-of-1 match won by team A.
    private func finishedMatch(teamA: [String], teamB: [String], createdAt: Date = Date()) -> MatchState {
        var state = MatchState(
            teamA: Team(players: teamA.map { Player(name: $0) }),
            teamB: Team(players: teamB.map { Player(name: $0) }),
            settings: MatchSettings(goldenPoint: true, setsToWin: 1),
            createdAt: createdAt
        )
        while !state.isFinished {
            state.addPoint(for: .teamA)
        }
        return state
    }

    func testStatsMatchPlayersByNameAcrossFreshUUIDs() {
        // Every match setup creates new Player UUIDs, so a saved player must
        // still be credited via their name.
        let match = finishedMatch(teamA: ["Nicolaj", "Anna"], teamB: ["Bo", "Carla"])
        let savedPlayer = Player(name: " nicolaj ")

        let stats = MatchStatistics.stats(for: savedPlayer, in: [match])
        XCTAssertEqual(stats.played, 1)
        XCTAssertEqual(stats.wins, 1)

        let loser = MatchStatistics.stats(for: Player(name: "Bo"), in: [match])
        XCTAssertEqual(loser.losses, 1)
    }

    func testHeadToHeadCountsOpponentsOnly() {
        let m1 = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"])
        let m2 = finishedMatch(teamA: ["C", "B"], teamB: ["A", "D"])

        let records = PlayerInsights.headToHead(for: Player(name: "A"), matches: [m1, m2])
        let vsC = records.first { $0.opponent.name == "C" }
        XCTAssertEqual(vsC?.wins, 1)
        XCTAssertEqual(vsC?.losses, 1)
        let vsB = records.first { $0.opponent.name == "B" }
        XCTAssertEqual(vsB?.wins, 0)
        XCTAssertEqual(vsB?.losses, 1)
        XCTAssertNil(records.first { $0.opponent.name == "A" })
    }

    func testPartnerStatsTrackWinRatePerPartner() {
        let m1 = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"])
        let m2 = finishedMatch(teamA: ["C", "D"], teamB: ["A", "B"])
        let m3 = finishedMatch(teamA: ["A", "C"], teamB: ["B", "D"])

        let records = PlayerInsights.partnerStats(for: Player(name: "A"), matches: [m1, m2, m3])
        let withB = records.first { $0.partner.name == "B" }
        XCTAssertEqual(withB?.played, 2)
        XCTAssertEqual(withB?.wins, 1)
        let withC = records.first { $0.partner.name == "C" }
        XCTAssertEqual(withC?.played, 1)
        XCTAssertEqual(withC?.wins, 1)
    }

    func testRatingsRewardWinnersAndStartAtBase() {
        let match = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"])
        // Seed everyone mid-scale so movement isn't clipped by the 1.0 floor.
        let seeds = ["a": 3.0, "b": 3.0, "c": 3.0, "d": 3.0]
        let ratings = PlayerInsights.ratings(matches: [match], seedRatings: seeds)

        XCTAssertEqual(ratings.count, 4)
        let winner = ratings.first { $0.player.name == "A" }!
        let loser = ratings.first { $0.player.name == "C" }!
        XCTAssertGreaterThan(winner.rating, 3.0)
        XCTAssertLessThan(loser.rating, 3.0)
        // Equal starting ratings: winners gain exactly what losers lose (matchK/2 = 0.1).
        XCTAssertEqual(winner.rating - 3.0, 0.1, accuracy: 0.0001)
        XCTAssertEqual(3.0 - loser.rating, 0.1, accuracy: 0.0001)
    }

    func testNewPlayersStartAtBottomOfScale() {
        // Unseeded players begin at 1.0; the losers can't drop below the floor.
        let match = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"])
        let ratings = PlayerInsights.ratings(matches: [match])

        XCTAssertEqual(PlayerRatingEntry.defaultRating, 1.0, accuracy: 0.0001)
        let winner = ratings.first { $0.player.name == "A" }!
        let loser = ratings.first { $0.player.name == "C" }!
        XCTAssertEqual(winner.rating, 1.1, accuracy: 0.0001)
        XCTAssertEqual(loser.rating, PlayerRatingEntry.minRating, accuracy: 0.0001)
    }

    func testSeedRatingStartsPlayerAtOfficialLevel() {
        let match = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"])
        // A is seeded at 5.0; the others fall back to the default.
        let ratings = PlayerInsights.ratings(matches: [match], seedRatings: ["a": 5.0])

        let seeded = ratings.first { $0.player.name == "A" }!
        // Winning from a big lead over default-rated opponents barely moves it.
        XCTAssertGreaterThan(seeded.rating, 5.0)
        XCTAssertLessThan(seeded.rating, 5.1)
    }

    func testRatingsStayWithinOfficialScale() {
        // A dominant team beating a weak team many times stays capped at 7.
        var matches: [MatchState] = []
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<200 {
            matches.append(finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"], createdAt: start.addingTimeInterval(Double(i))))
        }
        let ratings = PlayerInsights.ratings(matches: matches)
        let winner = ratings.first { $0.player.name == "A" }!
        let loser = ratings.first { $0.player.name == "C" }!
        XCTAssertLessThanOrEqual(winner.rating, PlayerRatingEntry.maxRating)
        XCTAssertGreaterThanOrEqual(loser.rating, PlayerRatingEntry.minRating)
    }

    func testUpsetMovesRatingMoreThanExpectedWin() {
        let day: TimeInterval = 86_400
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // A+B beat C+D twice to build a rating lead...
        let m1 = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"], createdAt: start)
        let m2 = finishedMatch(teamA: ["A", "B"], teamB: ["C", "D"], createdAt: start.addingTimeInterval(day))
        // ...then lose the third match as favorites.
        let m3 = finishedMatch(teamA: ["C", "D"], teamB: ["A", "B"], createdAt: start.addingTimeInterval(2 * day))

        // Seed mid-scale so the favorite has room to fall without hitting the floor.
        let seeds = ["a": 3.0, "b": 3.0, "c": 3.0, "d": 3.0]
        let afterTwo = PlayerInsights.ratings(matches: [m1, m2], seedRatings: seeds)
        let afterUpset = PlayerInsights.ratings(matches: [m1, m2, m3], seedRatings: seeds)
        let favoriteBefore = afterTwo.first { $0.player.name == "A" }!.rating
        let favoriteAfter = afterUpset.first { $0.player.name == "A" }!.rating

        // Losing as the favorite costs more than the even-odds delta (0.1).
        XCTAssertLessThan(favoriteAfter, favoriteBefore - 0.1)
    }

    func testAmericanoMatchupsFeedInsights() {
        let p = ["A", "B", "C", "D"].map { Player(name: $0) }
        var matchup = AmericanoMatchup(court: 1, teamA: Team(players: [p[0], p[1]]), teamB: Team(players: [p[2], p[3]]))
        for _ in 0..<15 { matchup.addPoint(to: .teamA, target: 16) }
        for _ in 0..<7 { matchup.addPoint(to: .teamB, target: 16) }
        matchup.addPoint(to: .teamA, target: 16)
        let round = AmericanoRound(index: 0, matchups: [matchup])
        let session = AmericanoSession(
            players: p,
            settings: AmericanoSettings(pointsPerRound: 16, numberOfCourts: 1, numberOfRounds: 1),
            rounds: [round]
        )

        let ratings = PlayerInsights.ratings(matches: [], americanoSessions: [session])
        let winner = ratings.first { $0.player.name == "A" }!
        XCTAssertGreaterThan(winner.rating, PlayerRatingEntry.defaultRating)
        // Americano rounds use half the K factor of a full match (roundK/2 = 0.05).
        XCTAssertEqual(winner.rating - PlayerRatingEntry.defaultRating, 0.05, accuracy: 0.0001)

        let h2h = PlayerInsights.headToHead(for: p[0], matches: [], americanoSessions: [session])
        XCTAssertEqual(h2h.first { $0.opponent.name == "C" }?.wins, 1)

        let partners = PlayerInsights.partnerStats(for: p[0], matches: [], americanoSessions: [session])
        XCTAssertEqual(partners.first { $0.partner.name == "B" }?.wins, 1)
    }
}
