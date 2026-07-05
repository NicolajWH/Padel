import Foundation
import CloudKit
import CoreLocation
import PadelKit

/// A shared match discovered near the user's location.
struct NearbySharedMatch: Identifiable {
    let code: String
    let court: Int
    let state: MatchState

    var id: String { code }
}

/// Shares a live match through CloudKit's public database so several players
/// can score the same match from their own iPhone + Apple Watch.
///
/// A match is published under a short join code (e.g. "K7WQ2M"). Everyone who
/// joins polls the record every few seconds and pushes their own updates. A
/// monotonically increasing `revision` decides which state is newest, so undo
/// (a shorter point log) still propagates correctly.
@MainActor
final class SharedMatchController: ObservableObject {
    @Published private(set) var shareCode: String?
    @Published private(set) var remoteState: MatchState?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private static let containerID = "iCloud.com.worsa.padel"
    private static let recordType = "SharedMatch"
    private static let codesDefaultsKey = "sharedMatchCodes"
    // No 0/O or 1/I so codes are easy to read out loud on court.
    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private var database: CKDatabase {
        CKContainer(identifier: Self.containerID).publicCloudDatabase
    }

    private var matchID: UUID?
    private var revision: Int = 0
    private var pollTask: Task<Void, Never>?

    var isSharing: Bool { shareCode != nil }

    // MARK: - Lifecycle

    /// Call when the live view appears. Resumes sharing if this match was
    /// already shared or joined earlier.
    func attach(to state: MatchState) {
        matchID = state.id
        if let code = Self.storedCode(for: state.id) {
            shareCode = code
            startPolling()
        }
    }

    func detach() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Sharing

    /// Publishes the match under a court number and (when available) the
    /// court's location, so other players nearby can join with one tap.
    func startSharing(_ state: MatchState, court: Int, location: CLLocation?) async {
        guard shareCode == nil else { return }
        isBusy = true
        defer { isBusy = false }

        let code = Self.generateCode()
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: code))
        Self.apply(state, revision: 1, to: record)
        record["code"] = code
        record["court"] = court
        if let location {
            record["location"] = location
        }
        do {
            let (saveResults, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            for case .failure(let saveError) in saveResults.values {
                throw saveError
            }
            revision = 1
            shareCode = code
            Self.storeCode(code, for: state.id)
            startPolling()
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    /// Pushes a locally produced state change to the shared record.
    func push(_ state: MatchState) async {
        guard let code = shareCode else { return }
        revision += 1
        let record = (try? await database.record(for: Self.recordID(for: code)))
            ?? CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: code))
        Self.apply(state, revision: revision, to: record)
        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        } catch {
            // Transient push failures are fine; the next poll reconciles.
        }
    }

    // MARK: - Joining

    /// Fetches the match published under `code`. Throws if it doesn't exist
    /// or iCloud is unavailable.
    static func fetchSharedMatch(code: String) async throws -> MatchState {
        let database = CKContainer(identifier: containerID).publicCloudDatabase
        let record = try await database.record(for: recordID(for: code))
        guard let data = record["state"] as? Data,
              let state = try? JSONDecoder().decode(MatchState.self, from: data) else {
            throw CKError(.unknownItem)
        }
        storeCode(normalize(code), for: state.id)
        return state
    }

    /// Finds active shared matches within `radius` meters of `location`,
    /// sorted by court number — so players on court just tap their court
    /// instead of typing a code.
    static func fetchNearbyMatches(around location: CLLocation, radius: Double = 500) async throws -> [NearbySharedMatch] {
        let database = CKContainer(identifier: containerID).publicCloudDatabase
        let predicate = NSPredicate(
            format: "distanceToLocation:fromLocation:(location, %@) < %f",
            location, radius
        )
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 25)

        let cutoff = Date().addingTimeInterval(-12 * 60 * 60)
        var matches: [NearbySharedMatch] = []
        for (_, result) in results {
            guard let record = try? result.get(),
                  let code = record["code"] as? String,
                  let data = record["state"] as? Data,
                  let state = try? JSONDecoder().decode(MatchState.self, from: data) else { continue }
            let finished = (record["finished"] as? Int ?? 0) == 1
            let createdAt = record.creationDate ?? Date()
            guard !finished, createdAt > cutoff else { continue }
            let court = record["court"] as? Int ?? 1
            matches.append(NearbySharedMatch(code: code, court: court, state: state))
        }
        for match in matches {
            storeCode(match.code, for: match.state.id)
        }
        return matches.sorted { $0.court < $1.court }
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
        guard let record = try? await database.record(for: Self.recordID(for: code)),
              let data = record["state"] as? Data,
              let incomingRevision = record["revision"] as? Int,
              let state = try? JSONDecoder().decode(MatchState.self, from: data) else { return }
        if incomingRevision > revision {
            revision = incomingRevision
            remoteState = state
        }
    }

    // MARK: - Helpers

    private static func apply(_ state: MatchState, revision: Int, to record: CKRecord) {
        record["state"] = (try? JSONEncoder().encode(state)) ?? Data()
        record["revision"] = revision
        record["matchID"] = state.id.uuidString
        record["finished"] = state.isFinished ? 1 : 0
    }

    private static func recordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "sharedmatch-\(normalize(code))")
    }

    static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func generateCode() -> String {
        String((0..<6).compactMap { _ in codeAlphabet.randomElement() })
    }

    static func storedCode(for matchID: UUID) -> String? {
        let dict = UserDefaults.standard.dictionary(forKey: codesDefaultsKey) as? [String: String]
        return dict?[matchID.uuidString]
    }

    private static func storeCode(_ code: String, for matchID: UUID) {
        var dict = (UserDefaults.standard.dictionary(forKey: codesDefaultsKey) as? [String: String]) ?? [:]
        dict[matchID.uuidString] = code
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
