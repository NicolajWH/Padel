import XCTest
@testable import PadelKit

final class SyncPayloadTests: XCTestCase {
    func testPlayerRosterKeepsOwnerFirstAndRemovesDuplicateSavedPlayer() {
        let owner = Player(name: "Nicolaj")
        let duplicate = Player(name: " nicolaj ")
        let partner = Player(name: "Anne Marie")
        let roster = PlayerRoster(owner: owner, savedPlayers: [duplicate, partner])

        XCTAssertEqual(roster.allPlayers.map(\.id), [owner.id, partner.id])
        XCTAssertEqual(roster.allPlayers.map(\.initials), ["N", "AM"])
    }

    func testPlayerRosterPayloadRoundTrips() {
        let roster = PlayerRoster(
            owner: Player(name: "Nicolaj"),
            savedPlayers: [Player(name: "Anne Marie")]
        )

        guard case .playerRoster(let decoded)? = SyncPayload.decode(SyncPayload.playerRoster(roster).encoded()) else {
            return XCTFail("Expected a player-roster payload")
        }
        XCTAssertEqual(decoded, roster)
    }
}
