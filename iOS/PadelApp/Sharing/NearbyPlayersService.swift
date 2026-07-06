import Foundation
import CloudKit
import CoreLocation

/// A player with the app discovered near the user's location.
struct NearbyPlayer: Identifiable {
    let id: String
    let name: String
}

/// Publishes "I'm here" presence for the local player and finds other
/// players who have the app nearby, through the same CloudKit public
/// database used for shared matches. This is what lets match and Americano
/// setup suggest the people standing on the court next to you.
///
/// Each device keeps a single `NearbyPlayer` record (name + location) keyed
/// by a stable per-device ID and re-saves it whenever the app comes to the
/// foreground, so the record's modification date doubles as "last seen".
/// Discovery filters out stale records and the local player.
enum NearbyPlayersService {
    static let discoveryEnabledKey = "nearbyDiscoveryEnabled"

    private static let containerID = "iCloud.com.worsa.padel"
    private static let recordType = "NearbyPlayer"
    private static let recordNamePrefix = "nearbyplayer-"
    private static let deviceIDKey = "nearbyPlayerDeviceID"
    /// How long a presence record counts as "at the court".
    private static let maxAge: TimeInterval = 3 * 60 * 60

    private static var database: CKDatabase {
        CKContainer(identifier: containerID).publicCloudDatabase
    }

    /// Discovery defaults to on; Settings offers the opt-out.
    static var isDiscoveryEnabled: Bool {
        UserDefaults.standard.object(forKey: discoveryEnabledKey) as? Bool ?? true
    }

    private static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: deviceIDKey)
        return fresh
    }

    /// Publishes (or refreshes) the local player's presence. Best-effort:
    /// failures are ignored because the record is re-saved often anyway.
    static func publish(name: String, location: CLLocation) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDiscoveryEnabled, !trimmed.isEmpty else { return }
        let record = CKRecord(recordType: recordType, recordID: localRecordID())
        record["name"] = trimmed
        record["location"] = location
        _ = try? await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    /// Removes the local player's presence record — used when the user
    /// turns off discovery in Settings.
    static func unpublish() async {
        _ = try? await database.modifyRecords(saving: [], deleting: [localRecordID()])
    }

    /// Finds players seen within `radius` meters recently, sorted by name.
    static func fetchNearby(around location: CLLocation, radius: Double = 500) async throws -> [NearbyPlayer] {
        let predicate = NSPredicate(
            format: "distanceToLocation:fromLocation:(location, %@) < %f",
            location, radius
        )
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 50)

        let cutoff = Date().addingTimeInterval(-maxAge)
        let ownID = localRecordID()
        var players: [NearbyPlayer] = []
        for (recordID, result) in results {
            guard recordID != ownID,
                  let record = try? result.get(),
                  (record.modificationDate ?? record.creationDate ?? Date()) > cutoff,
                  let name = record["name"] as? String,
                  !name.isEmpty else { continue }
            players.append(NearbyPlayer(id: recordID.recordName, name: name))
        }
        return players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func localRecordID() -> CKRecord.ID {
        CKRecord.ID(recordName: recordNamePrefix + deviceID)
    }
}
