import Foundation
import CloudKit
import CoreLocation
import PadelKit

/// What kind of game a shared CloudKit record carries.
enum SharedGameKind: Int {
    case match = 0
    case americano = 1
}

/// A shared game discovered near the user's location.
struct NearbyShared: Identifiable {
    enum Content {
        case match(MatchState)
        case americano(AmericanoSession)
    }

    let code: String
    let court: Int
    let content: Content

    var id: String { code }
}

/// Shares a live match or Americano session through CloudKit's public
/// database so several players can score the same game from their own
/// iPhone + Apple Watch.
///
/// The record schema is deliberately tiny (state, revision, court, kind,
/// location) so it is quick to set up in CloudKit Console. The join code is
/// derived from the record name; whether a game is finished is derived from
/// the decoded state.
///
/// A monotonically increasing `revision` decides which state is newest, so
/// undo (a shorter point log) still propagates correctly.
@MainActor
final class SharedMatchController: ObservableObject {
    @Published private(set) var shareCode: String?
    @Published private(set) var remoteMatch: MatchState?
    @Published private(set) var remoteAmericano: AmericanoSession?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private static let containerID = "iCloud.com.worsa.padel"
    private static let recordType = "SharedMatch"
    private static let recordNamePrefix = "sharedmatch-"
    private static let codesDefaultsKey = "sharedMatchCodes"
    // No 0/O or 1/I so codes are easy to read out loud on court.
    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private static var database: CKDatabase {
        CKContainer(identifier: containerID).publicCloudDatabase
    }

    private var revision: Int = 0
    private var pollTask: Task<Void, Never>?

    var isSharing: Bool { shareCode != nil }

    // MARK: - Lifecycle

    /// Call when a live view appears. Resumes sharing if this game was
    /// already shared or joined earlier.
    func attach(id: UUID) {
        if let code = Self.storedCode(for: id) {
            shareCode = code
            startPolling()
        }
    }

    func detach() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Sharing

    /// Publishes a match under a court number and (when available) the
    /// court's location, so other players nearby can join with one tap.
    func startSharingMatch(_ state: MatchState, court: Int, location: CLLocation?) async {
        await startSharing(
            id: state.id,
            data: (try? JSONEncoder().encode(state)) ?? Data(),
            kind: .match,
            court: court,
            location: location
        )
    }

    /// Publishes an Americano session so players nearby can join, pick who
    /// they are, and score their own courts.
    func startSharingAmericano(_ session: AmericanoSession, location: CLLocation?) async {
        await startSharing(
            id: session.id,
            data: (try? JSONEncoder().encode(session)) ?? Data(),
            kind: .americano,
            court: 0,
            location: location
        )
    }

    private func startSharing(id: UUID, data: Data, kind: SharedGameKind, court: Int, location: CLLocation?) async {
        guard shareCode == nil else { return }
        isBusy = true
        defer { isBusy = false }

        let code = Self.generateCode()
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: code))
        record["state"] = data
        record["revision"] = 1
        record["kind"] = kind.rawValue
        record["court"] = court
        if let location {
            record["location"] = location
        }
        do {
            let (saveResults, _) = try await Self.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            for case .failure(let saveError) in saveResults.values {
                throw saveError
            }
            revision = 1
            shareCode = code
            Self.storeCode(code, for: id)
            startPolling()
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    // MARK: - Pushing local changes

    func pushMatch(_ state: MatchState) async {
        await push(data: (try? JSONEncoder().encode(state)) ?? Data())
    }

    func pushAmericano(_ session: AmericanoSession) async {
        await push(data: (try? JSONEncoder().encode(session)) ?? Data())
    }

    private func push(data: Data) async {
        guard let code = shareCode else { return }
        revision += 1
        guard let record = try? await Self.database.record(for: Self.recordID(for: code)) else { return }
        record["state"] = data
        record["revision"] = revision
        do {
            _ = try await Self.database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        } catch {
            // Transient push failures are fine; the next poll reconciles.
        }
    }

    // MARK: - Discovery & joining

    /// Finds active shared games within `radius` meters of `location`,
    /// matches sorted by court number first, then Americano sessions.
    static func fetchNearby(around location: CLLocation, radius: Double = 500) async throws -> [NearbyShared] {
        let predicate = NSPredicate(
            format: "distanceToLocation:fromLocation:(location, %@) < %f",
            location, radius
        )
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 25)

        let cutoff = Date().addingTimeInterval(-12 * 60 * 60)
        var games: [NearbyShared] = []
        for (recordID, result) in results {
            guard let record = try? result.get(),
                  (record.creationDate ?? Date()) > cutoff,
                  let game = decode(record: record, recordID: recordID),
                  !isFinished(game) else { continue }
            games.append(game)
        }
        for game in games {
            storeCode(game.code, for: gameID(of: game))
        }
        return games.sorted { a, b in
            switch (a.content, b.content) {
            case (.match, .americano): return true
            case (.americano, .match): return false
            default: return a.court < b.court
            }
        }
    }

    /// Fetches the game published under `code`. Throws if it doesn't exist
    /// or iCloud is unavailable.
    static func fetchShared(code: String) async throws -> NearbyShared {
        let recordID = recordID(for: code)
        let record = try await database.record(for: recordID)
        guard let game = decode(record: record, recordID: recordID) else {
            throw CKError(.unknownItem)
        }
        storeCode(game.code, for: gameID(of: game))
        return game
    }

    // MARK: - Polling

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.fetchLatest()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func fetchLatest() async {
        guard let code = shareCode else { return }
        let recordID = Self.recordID(for: code)
        guard let record = try? await Self.database.record(for: recordID),
              let incomingRevision = record["revision"] as? Int,
              incomingRevision > revision,
              let game = Self.decode(record: record, recordID: recordID) else { return }
        revision = incomingRevision
        switch game.content {
        case .match(let state): remoteMatch = state
        case .americano(let session): remoteAmericano = session
        }
    }

    // MARK: - Helpers

    private static func decode(record: CKRecord, recordID: CKRecord.ID) -> NearbyShared? {
        guard let data = record["state"] as? Data else { return nil }
        let code = String(recordID.recordName.dropFirst(recordNamePrefix.count))
        let court = record["court"] as? Int ?? 1
        let kind = SharedGameKind(rawValue: record["kind"] as? Int ?? 0) ?? .match
        switch kind {
        case .match:
            guard let state = try? JSONDecoder().decode(MatchState.self, from: data) else { return nil }
            return NearbyShared(code: code, court: court, content: .match(state))
        case .americano:
            guard let session = try? JSONDecoder().decode(AmericanoSession.self, from: data) else { return nil }
            return NearbyShared(code: code, court: court, content: .americano(session))
        }
    }

    private static func isFinished(_ game: NearbyShared) -> Bool {
        switch game.content {
        case .match(let state): return state.isFinished
        case .americano(let session): return session.isComplete
        }
    }

    private static func gameID(of game: NearbyShared) -> UUID {
        switch game.content {
        case .match(let state): return state.id
        case .americano(let session): return session.id
        }
    }

    private static func recordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordNamePrefix + normalize(code))
    }

    static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func generateCode() -> String {
        String((0..<6).compactMap { _ in codeAlphabet.randomElement() })
    }

    static func storedCode(for gameID: UUID) -> String? {
        let dict = UserDefaults.standard.dictionary(forKey: codesDefaultsKey) as? [String: String]
        return dict?[gameID.uuidString]
    }

    private static func storeCode(_ code: String, for gameID: UUID) {
        var dict = (UserDefaults.standard.dictionary(forKey: codesDefaultsKey) as? [String: String]) ?? [:]
        dict[gameID.uuidString] = code
        UserDefaults.standard.set(dict, forKey: codesDefaultsKey)
    }

    static func friendlyMessage(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return String(localized: "iCloud is required to share matches. Sign in to iCloud on this iPhone and try again.")
            case .networkUnavailable, .networkFailure:
                return String(localized: "No internet connection. Try again when you're back online.")
            case .unknownItem:
                return String(localized: "Match not found. Check the code and try again.")
            default:
                break
            }
        }
        return String(localized: "Something went wrong. Please try again.")
    }
}

/// Remembers which player the local user is in a joined Americano session,
/// so their row can be highlighted in standings.
enum AmericanoIdentity {
    private static let key = "americanoIdentities"

    static func playerID(for sessionID: UUID) -> UUID? {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        guard let raw = dict?[sessionID.uuidString] else { return nil }
        return UUID(uuidString: raw)
    }

    static func setPlayerID(_ playerID: UUID, for sessionID: UUID) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        dict[sessionID.uuidString] = playerID.uuidString
        UserDefaults.standard.set(dict, forKey: key)
    }
}
